// Supabase Edge Function: create Stripe Checkout session for $10 listing fee
// Deploy: npx supabase functions deploy create-checkout
// Secrets: STRIPE_SECRET_KEY, STRIPE_PRICE_ID, SITE_URL

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import Stripe from 'https://esm.sh/stripe@14.21.0?target=deno'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.1'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const stripeKey = Deno.env.get('STRIPE_SECRET_KEY')
    const priceId = Deno.env.get('STRIPE_PRICE_ID')
    const siteUrl = Deno.env.get('SITE_URL') || 'http://localhost:3000'
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseAnon = Deno.env.get('SUPABASE_ANON_KEY')!

    if (!stripeKey || !priceId) {
      throw new Error('Missing STRIPE_SECRET_KEY or STRIPE_PRICE_ID')
    }

    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'Not authenticated' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const supabase = createClient(supabaseUrl, supabaseAnon, {
      global: { headers: { Authorization: authHeader } },
    })

    const { data: { user }, error: userErr } = await supabase.auth.getUser()
    if (userErr || !user) {
      return new Response(JSON.stringify({ error: 'Invalid session' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const body = await req.json()
    const propertyId = body.property_id as string
    if (!propertyId) {
      return new Response(JSON.stringify({ error: 'property_id required' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // Verify ownership
    const { data: prop, error: propErr } = await supabase
      .from('properties')
      .select('id, owner_id, title, status')
      .eq('id', propertyId)
      .single()

    if (propErr || !prop || prop.owner_id !== user.id) {
      return new Response(JSON.stringify({ error: 'Property not found' }), {
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const stripe = new Stripe(stripeKey, {
      apiVersion: '2023-10-16',
      httpClient: Stripe.createFetchHttpClient(),
    })

    const session = await stripe.checkout.sessions.create({
      mode: 'payment',
      payment_method_types: ['card'],
      line_items: [{ price: priceId, quantity: 1 }],
      customer_email: user.email,
      client_reference_id: user.id,
      metadata: {
        property_id: propertyId,
        user_id: user.id,
      },
      success_url: `${siteUrl}/?payment=success&session_id={CHECKOUT_SESSION_ID}&property_id=${propertyId}`,
      cancel_url: `${siteUrl}/?payment=cancelled&property_id=${propertyId}`,
    })

    // Store session on property + payment row
    await supabase
      .from('properties')
      .update({
        stripe_session_id: session.id,
        status: 'pending_payment',
        payment_status: 'unpaid',
        updated_at: new Date().toISOString(),
      })
      .eq('id', propertyId)

    await supabase.from('payments').upsert({
      user_id: user.id,
      property_id: propertyId,
      stripe_session_id: session.id,
      amount_cents: 1000,
      currency: 'usd',
      status: 'pending',
    }, { onConflict: 'stripe_session_id' })

    return new Response(JSON.stringify({ url: session.url, session_id: session.id }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Unknown error'
    return new Response(JSON.stringify({ error: message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
