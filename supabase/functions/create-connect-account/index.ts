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
    const { vendor_id, email, business_name, return_url, refresh_url } = await req.json()

    if (!vendor_id || !email || !business_name) {
      throw new Error('vendor_id, email, and business_name are required')
    }

    // Create Stripe Connect account
    const account = await stripe.accounts.create({
      type: 'express',
      email: email,
      business_type: 'individual',
      business_profile: {
        name: business_name,
        product_description: 'Event ticketing and booking services',
      },
      capabilities: {
        card_payments: { requested: true },
        transfers: { requested: true },
      },
    })

    // Create account link for onboarding
    const accountLink = await stripe.accountLinks.create({
      account: account.id,
      refresh_url: refresh_url || return_url,
      return_url: return_url,
      type: 'account_onboarding',
    })

    // Save to Supabase
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const { error } = await supabaseClient
      .from('stripe_accounts')
      .upsert({
        vendor_id: vendor_id,
        account_id: account.id,
        account_type: 'express',
        charges_enabled: false,
        payouts_enabled: false,
        details_submitted: false,
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      })

    if (error) {
      console.error('Supabase error:', error)
    }

    return new Response(
      JSON.stringify({
        account_id: account.id,
        url: accountLink.url,
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
