# Constant mint under demurrage

## Mint 1 CRC per hour, always

In demurraged units, Circles mints one CRC per hour per person, every day - maximally, as people need to
show up to mint.

We can rewrite for successive days this first constraint with help of a yet unknown function `D(i)`,
we'll call the global demurrage function.
`D(i)` takes values over `i` integer numbers from zero to arbitrary positive N, where `i` is the i-th day
since day zero. We define `D(0)` to be equal to `1`.

If we assume that `D` is a strict monotonic increasing function, and as a consequence also never
becomes zero, we can write for the (demurraged) mint each day `i`:
  
    day 0: D(0)/D(0) CRC/hr
    day 1: D(1)/D(1) CRC/hr
    ...
    day N: D(N)/D(N) CRC/hr

which is by construction, trivially, 1 CRC/hr each day, our first constraint.

Then we can **define** the "inflationary" mint as:
    
    day 0: D(0) CRC/hr
    day 1: D(1) CRC/hr
    ...
    day N: D(N) CRC/hr

and accordingly we define the demurraged balance on day `i`, given an inflationary amount as:
  
    B(i) = balance(i) = inflationary_balance / D(i)

We note that this definition of the "demurraged balance" function is linear in sums of the inflationary
balance, so all mints, Circles received and Circles spent are linear under the demurraged balance function.
We can then, without loss of generality, consider a single balance amount, as all operations are
linear combinations on the inflationary amounts.

## Determining `D(i)`

Our second constraint is that the demurraged balances have a 7% per annum demurrage, if it is accounted for
on a yearly basis.

However, we want to correct for the demurrage on a daily basis. To adhere to conventional notations we will
write the conversion out twice, once as standard percentages, and once as a reduction factor, but simply to
pendantically show they are saying the same thing.

All balances are understood as demurraged balances (as that is our constraint), and denoted with B(time). We denote 7% p.a. demurrage as γ'.

After one year, our balance is corrected for 7% or γ':

    B(1 yr) = (1 - γ') B(0 yr)

and the same formula, but if we would adjust the demurrage daily, what would the equivalent demurrage rate be?
We can call this unknown demurrage rate Γ' and write for `N=365.25` (days in a year):

    B(N days) = (1 - Γ'/N)^N B(0 days)

and we know that the balances in both equations are equal (as we're only rewriting the time unit), so

    Γ' = N(1 - (1-γ')^(1/N))

or an equivalent demurrage rate of 7,26% per annum on a daily accounted basis.

For our purposes we don't need to know the percentage though, we simply need to determine D(i).
If we call `γ = 1 - γ'`, and `Γ = 1- Γ'/N`, then we can rewrite the above equations as

    B(1 yr) = γ B(0 yr)

and

    B(N days) = Γ^N B(0 days)

and directly see that

    Γ = γ^(1/N) = 0.99980133200859895743...

Now we have a formula for the demurraged balances expressed in days:

    B(i + d) = Γ^i B(d)

for any number `d` and `i` days. Again without loss of generality we can proceed with `d=0`
and write this equation for `i=1, i=2, ...` and remember that 
 - `B(i) = inflationary.amount / D(i)`
 - and this was a linear function, so considering a constant inflationary amount is sufficient,
   as any additional mints, or sending and receiving transfers over time can be written as a sum
   over which the same argument holds.

We write:
   
    1/D(1)   = Γ^1 1/D(0)
    1/D(2)   = Γ^2 1/D(0)
    ...
    1/D(n)   = Γ^n 1/D(0)
    1/D(n+1) = Γ^(n+1) 1/D(0) 
    
We already defined `D(0) = 1`, and see that `D(n+1) = (1/Γ) D(n)`, so by induction we comclude
that the global demurrage function `D(i)` is

    D(i) = (1/Γ)^i

## Conclusion

So we can conclude that if we substitute this in our definition of "inflationary mint"
then one day `i` the protocol should mint as inflationary amounts

    (1/Γ)^i CRC/hour

and the demurraged balance function can adjust these inflationary amounts as

    B(i) = Γ^i inflationary_balance