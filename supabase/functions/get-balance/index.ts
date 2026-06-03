import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import Stripe from 'https://esm.sh/stripe@14.5.0?target=deno'

const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY') || '', {
  apiVersion: '2023-10-16',
  httpClient: Stripe.createFetchHttpClient(),
})

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { account_id } = await req.json()

    if (!account_id) {
      throw new Error('account_id is required')
    }

    // Get balance from Stripe Connect account
    const balance = await stripe.balance.retrieve({
      stripeAccount: account_id,
    })

    // Get the available and pending amounts (in USD)
    const availableBalance = balance.available.find(b => b.currency === 'usd') || { amount: 0, currency: 'usd' }
    const pendingBalance = balance.pending.find(b => b.currency === 'usd') || { amount: 0, currency: 'usd' }

    return new Response(
      JSON.stringify({
        available: availableBalance.amount,
        pending: pendingBalance.amount,
        currency: availableBalance.currency,
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    )
  } catch (error) {
    return new Response(
      JSON.stringify({
        error: error.message,
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      }
    )
  }
})
