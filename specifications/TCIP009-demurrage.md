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

For our purposes we don't need to know the percentage though, we simply need to determine `D(i)`.
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
 - `B(i) = inflationary_balance / D(i)`
 - and this was a linear function, so considering a constant inflationary amount is sufficient,
   as any additional mints, or sending and receiving transfers over time can be written as a sum
   over which the same argument holds.

We write:
   
    1/D(1)   = Γ^1 1/D(0)
    1/D(2)   = Γ^2 1/D(0)
    ...
    1/D(n)   = Γ^n 1/D(0)
    1/D(n+1) = Γ^(n+1) 1/D(0) 
    
We already defined `D(0) = 1`, and see that `D(n+1) = (1/Γ) D(n)`, so by induction we conclude
that the global demurrage function `D(i)` is

    D(i) = (1/Γ)^i

## Summarizing mint and demurrage

So we can conclude that if we substitute this in our definition of "inflationary mint"
then on day `i` the protocol should mint as inflationary amounts

    (1/Γ)^i CRC/hour

and the demurraged balance function can adjust these inflationary amounts as

    B(i) = Γ^i inflationary_balance

## Calculating mint

There is a maximum period of up to 14 days over which people can claim past hours
as Circles to be minted. Older Circles from preceding days should be appropriately demurraged. 

In general we can say their last mint was on day `A` (since day zero of this global demurrage function `D(0)`)
at a timestamp `a` (in seconds unix time). Similarly upon making the claim, it is now day `B` and timestamp `b`.

We could handle all the special case of where `A=B`, ie. last mint and now are on the same day, or `B-A = 0`, and `B-A > 1`,
as for `A` different from `B`, for each day we should apply the appropriate demurrage to the mintable amounts.

However, we can make a simpler implementation, and first consider
the full 24 hours for all the days `[A, B]`,
ignoring the timestamps `a` and `b`. If we do that, we have overcounted,
so we can subtract the time in `A` leading up to `a`
and subtract the time in `B` after `b`, at the appropriate demurraged rate of 
respective day `A` and `B`.

### Calculating full mint days

If we call `H = 24 CRC/day` and `M(i)` the mint on day `i`; we span over `n` days, or `B-A=n; A=d-n; B=d` for today `d`;
and lastly rename `β=1/Γ`, we can write for the overcounted mint of full days:

    H SUM_{i=A..B} M(i)
    = H SUM_{i=A..B} (1/Γ)^i
    = H SUM_{i=d-n..d} β^i
    = H β^(d-n) ( SUM_{i=0..n-1} β^i + β^n ) 
    = H β^(d-n) ( (β^n - 1)/(β - 1) θ(n>0) + β^n )    (*)
    = H β^d ( (β^n - 1)/(β^(n+1) - β^n) θ(n>0) + 1 )

The above has two factors, one is `β^d` which depends on the current day `d`,
and a second factor only depending on `n=B-A` which stretches over maximum
two weeks of outstanding mint `n ∈ {0, ..., 14}`.

(*) note `θ(n>0)` is a step function equals `1` for `n>0` and `0` for `n=0`,
as the `SUM` term did not return any terms for `n=0`.

So effectively for the complicated second factor we have a lookup table 
which is only depending on the difference of days over which we are minting:

    H (β^n - 1)/(β^(n+1) - β^n) + β^n for n > 0 

This makes the implementation extremely gas efficient because we can read
the lookup table from storage, and only once per day do we need
to calculate `β^d` and cache it until the next day.

For the code implementation in solidity, we want to use the 128 bit signed integer 
fixed point representation, which is calculated by multiplying the fraction with
`2**64`. If we calculate numerical values for this lookup table,
and the value of `β` is taken from 7% p.a. daily demurrage (see above).

    β=1.0001987074682146291562714890133039617432343970799554367508

```
n    T(n) (up to 25 decimals)                64x64 Fixed Int (rounded)     
---------------------------------------------------------------------------
0    24.0000000000000000000000000            442721857769029238784         
1    47.9952319682063749783347218            885355760875826166476         
2    71.9856968518744243107975483            1327901726794166863126        
3    95.9713955980712580655108804            1770359772994355928788        
4    119.9523291536758343901178951           2212729916943227173193        
5    143.9284984653789968915466652           2655012176104144305282        
6    167.8999044796835120083481164           3097206567937001622606        
7    191.8665481429041063756092976           3539313109898224700583        
8    215.8284304011675041824434382           3981331819440771081628        
9    239.7855522004124645220582683           4423262714014130964135        
10   263.7379144863898187344040757           4865105811064327891331        
11   287.6855182046625077414029740           5306861128033919439986        
12   311.6283643006056193747608561           5748528682361997908993        
13   335.5664537194064256963635055           6190108491484191007805        
14   359.4997874060644203112583400           6631600572832662544739 
```

(To reproduce the table see the python script in `../script/mint_lookuptable.py`.)

So for the full mint (24hours per day), we now simply compute `β^d`, where `d` is today's day
and multiply it with the value for the table `T(n)`

    β^d * T(n)

### Correcting mint for overcounting

As mentioned before, we now have overcounted, because in day `A` we started at timestamp `a`
and on day `B` we ended the mint at (now) timestamp `b`. So we should subtract these amounts.

If for shorthand we call `k` the number of seconds in day `A` up to `a`,
and we call `l` the number of seconds remaining in day `B` after `b`
then we write for these two terms

    β^(d-n) * k / 3600 * 1 CRC
    β^d * l / 3600 * 1 CRC
    
or combined

    β^d * T(n) - β^(d-n) * k / 3600 -  β^d * l / 3600
    = β^d * (T(n) - β^(-n) * k / 3600 - l / 3600)

Which again is only dependant on `β^d` and now two lookup tables `R(n) = β^(-n)` and `T(n)`, together with trivial counting of `k` and `l`.

We list the the table `R(n)` here for validation with the code implementation:

```
n    R(n) = Beta^(-n)                        64x64 Fixed (20 or 21 digits) 
---------------------------------------------------------------------------
0    1.0000000000000000000000000             18446744073709551616          
1    0.9998013320085989574306134             18443079296116538654          
2    0.9996027034861687221859511             18439415246597529027          
3    0.9994041144248680731130555             18435751925007877736          
4    0.9992055648168573468586256             18432089331202968517          
5    0.9990070546542984375595321             18428427465038213837          
6    0.9988085839293547965333938             18424766326369054888          
7    0.9986101526341914319692159             18421105915050961582          
8    0.9984117607609749086180892             18417446230939432544          
9    0.9982134083018733474839513             18413787273889995104          
10   0.9980150952490564255144086             18410129043758205300          
11   0.9978168215946953752916208             18406471540399647861          
12   0.9976185873309629847232451             18402814763669936209          
13   0.9974203924500335967334437             18399158713424712450          
14   0.9972222369440831089539514             18395503389519647372 
```

To convert this to attoCRC we can either allocate 1 CRC per completed (clock's) hour, which would result from
the integer division `/ 3600` as mentioned above. In that case we simply have to multiply our previous result
times `EXA = 10**18`. The extra hour gets subtracted because of the integer division to hours, to not overcount
the current incomplete hour:

    β^d * (T(n) - R(n) * k / 3600 - l / 3600 - 1) * EXA

Or we can issue mint accurate up to the second of claiming and then we'd write

    β^d * T(n) * EXA - β^d * (R(n) * k + l ) * EXA / 3600

To reinforce that per hour everyone receives one Circle, we opt for the first implementation.

## Numerical accuracy

When we store the inflationary value of a demurraged amount,
we have to divide the demurraged amountby `Γ^i` (which is smaller than one)
so we incur numerical inaccuracies in the stored value.

Todo: write out the full list of arguments why we revert to storing demurraged amounts. But in the interest of time, first complete the code

## Calculating issuance in demurraged units.

We follow the same logic as before, and same naming conventions, so we write
for the full mint:

    H SUM_{i=A..B} M(i)
    = H SUM_{i=A..B} Γ^(B-i)
    = H SUM_{i=0..n} Γ^i
    = H ( SUM_{i=0..n-1} Γ^i + Γ^n ) 
    = H ( (Γ^n - 1)/(Γ - 1) θ(n>0) + Γ^n )    (*)

