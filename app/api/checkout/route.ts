import { NextResponse } from 'next/server'
import { stripe } from '@/lib/stripe'
import { getPetById, getPetPrice, RARITY_COLORS } from '@/lib/pets'
import type { PetVariant } from '@/lib/pets'

export async function POST(req: Request) {
  try {
    const { petId, variant, quantity } = (await req.json()) as {
      petId: string
      variant: PetVariant
      quantity: number
    }

    const pet = getPetById(petId)
    if (!pet) {
      return NextResponse.json({ error: 'Pet not found' }, { status: 404 })
    }

    if (!Number.isInteger(quantity) || quantity < 1 || quantity > 50) {
      return NextResponse.json({ error: 'Invalid quantity' }, { status: 400 })
    }

    const unitPrice = getPetPrice(pet, variant)
    const unitAmountCents = Math.round(unitPrice * 100)

    const baseUrl = process.env.NEXT_PUBLIC_URL || 'http://localhost:3000'

    const session = await stripe.checkout.sessions.create({
      payment_method_types: ['card'],
      mode: 'payment',
      line_items: [
        {
          quantity,
          price_data: {
            currency: 'usd',
            unit_amount: unitAmountCents,
            product_data: {
              name: `${pet.name} (${variant})`,
              description: `${pet.rarity} Adopt Me Pet — ${pet.description}`,
              metadata: {
                petId: pet.id,
                rarity: pet.rarity,
                variant,
              },
            },
          },
        },
      ],
      success_url: `${baseUrl}/success?session_id={CHECKOUT_SESSION_ID}`,
      cancel_url: `${baseUrl}/shop`,
      metadata: {
        petId: pet.id,
        petName: pet.name,
        variant,
        quantity: quantity.toString(),
      },
      custom_text: {
        submit: {
          message: '🐾 Your pet will be delivered to your account within minutes of payment.',
        },
      },
    })

    return NextResponse.json({ url: session.url })
  } catch (err) {
    console.error('Checkout error:', err)
    return NextResponse.json({ error: 'Failed to create checkout session' }, { status: 500 })
  }
}
