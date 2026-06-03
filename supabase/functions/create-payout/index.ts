import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import Stripe from 'https://esm.sh/stripe@14.5.0?target=deno'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.38.4'

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
    const { vendor_id, account_id, amount, currency = 'usd' } = await req.json()

    if (!vendor_id || !account_id || !amount) {
      throw new Error('vendor_id, account_id, and amount are required')
    }

    // Create payout via Stripe Connect
    const payout = await stripe.payouts.create(
      {
        amount: amount, // Amount in cents
        currency: currency,
      },
      {
        stripeAccount: account_id,
      }
    )

    // Save payout record to Supabase
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const { error } = await supabaseClient
      .from('payout_records')
      .insert({
        vendor_id: vendor_id,
        stripe_payout_id: payout.id,
        amount: amount / 100, // Convert cents to dollars for storage
        currency: currency,
        status: payout.status,
        arrival_date: new Date(payout.arrival_date * 1000).toISOString(),
        created_at: new Date().toISOString(),
      })

    if (error) {
      console.error('Supabase error:', error)
    }

    return new Response(
      JSON.stringify({
        payout_id: payout.id,
        amount: payout.amount,
        status: payout.status,
        arrival_date: payout.arrival_date,
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
