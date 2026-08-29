// Stripe webhook — marks listing paid after successful Checkout
// Deploy: npx supabase functions deploy stripe-webhook --no-verify-jwt
// Secrets: STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET
// Also set in config.toml: [functions.stripe-webhook] verify_jwt = false

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import Stripe from 'https://esm.sh/stripe@14.21.0?target=deno'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.1'

serve(async (req) => {
  const stripeKey = Deno.env.get('STRIPE_SECRET_KEY')
  const webhookSecret = Deno.env.get('STRIPE_WEBHOOK_SECRET')
  const supabaseUrl = Deno.env.get('SUPABASE_URL')!
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

  if (!stripeKey || !webhookSecret) {
    return new Response('Missing Stripe secrets', { status: 500 })
  }

  const stripe = new Stripe(stripeKey, {
    apiVersion: '2023-10-16',
    httpClient: Stripe.createFetchHttpClient(),
  })

  const signature = req.headers.get('stripe-signature')
  if (!signature) {
    return new Response('No signature', { status: 400 })
  }

  const body = await req.text()
  let event: Stripe.Event

  try {
    event = await stripe.webhooks.constructEventAsync(body, signature, webhookSecret)
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Invalid signature'
    return new Response(`Webhook Error: ${message}`, { status: 400 })
  }

  if (event.type === 'checkout.session.completed') {
    const session = event.data.object as Stripe.Checkout.Session
    const propertyId = session.metadata?.property_id
    const userId = session.metadata?.user_id || session.client_reference_id

    const supabase = createClient(supabaseUrl, serviceKey)

    if (propertyId) {
      await supabase
        .from('properties')
        .update({
          payment_status: 'paid',
          status: 'pending_review',
          stripe_session_id: session.id,
          updated_at: new Date().toISOString(),
        })
        .eq('id', propertyId)
    }

    await supabase.from('payments').upsert({
      user_id: userId,
      property_id: propertyId,
      stripe_session_id: session.id,
      amount_cents: session.amount_total ?? 1000,
      currency: session.currency ?? 'usd',
      status: 'paid',
    }, { onConflict: 'stripe_session_id' })
  }

  return new Response(JSON.stringify({ received: true }), {
    headers: { 'Content-Type': 'application/json' },
  })
})
