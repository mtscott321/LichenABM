extensions [ rnd ]

breed [algae alga]
algae-own [health]
breed [mycelae mycelia]
mycelae-own [food temp_food]

directed-link-breed [streams stream] ;;mycelae stream link
directed-link-breed [symbios symbio] ;;mycelae to aplanospore link
undirected-link-breed [overlaps overlap]
overlaps-own [strength]

globals [mycelae_size
  algae_starting_size
  parenthood_size
  delta]

to setup
  ca
  reset-ticks

  ;;setting all the kinda boring globals that I dont' want to make sliders
  set algae_starting_size 5
  set parenthood_size 10
  set delta 1 ;;how much to stochastically wiggle
  set mycelae_size 5

  ;;creating the starting agents. This will eventually depend on the way we want to start (random, isidia, soredia, etc)
  create-mycelae 10 [set shape "line" set color red set size mycelae_size set food 1]

  create-algae 1 [set shape "circle" set color green set size algae_starting_size set health 100 ]


end



to go

  ;;algae growth
  ;;if the aplanospore is healthy
  ask algae [
    if random 100 < health [
      grow_algae who ;if this algae is healthy, grow it
    ]
    if health <= 0 [die]
    wiggle who
  ]
  ask overlaps [die]
  check_collisions
  fix_collisions

  ;;mycelial growth
  ;;mycelae get nutrients from algae
  nutrients

  ;;mycelae send nutrients to neighbors
  mycelial_diffusion

  ;;mycelae grow if they have enough food -- each one has a certain branching probability

  ;;change mycelial colors to show food flow
  mycelial_color
  ;;associate mycelae with algae
  associate

   carefully [
    let which random-float (branching + intercalary + apical)
    if which < branching [ ;;then we will do branching
      ;; get an agent with preexisting downstreams
      let trash grow_fungi [who] of one-of mycelae with [count my-out-links > 0]
    ]
    ifelse which >= branching and which < intercalary + branching [ ;;then we will do intercalary
      intercalary_grow [who] of one-of mycelae with [count my-out-links > 0]
    ]
    [ ;;then we will do apical
      let trash grow_fungi [who] of one-of mycelae with [count my-out-links = 0]
    ]
  ] []

  tick


end


to grow_algae [id]
  ask turtle id [
    if size < parenthood_size [set size size + growth_rate]
    if size >= parenthood_size and count my-symbios > 0 [ ;aplanospore only gets punctured if there are mycelae connected
      ;;get the information to make the children
      let x xcor
      let y ycor
      ask my-symbios [die]
      let k 0
      ;;make the children
      hatch-algae 1 [set size algae_starting_size set health 100]
      let n 2 + random 5
      while [k < n] [
        let newx x + 2.5 * algae_starting_size * sin((360 / n) * k)
        let newy y + 2.5 * algae_starting_size * cos((360 / n) * k)
        hatch-algae 1 [set xcor newx set ycor newy set size algae_starting_size set health 100]
        set k k + 1
      ]
      die

    ]

  ]
end

;;this is where I call it Brownian motion to sound smart
to wiggle [id]
  ask turtle id [
    if count my-symbios = 0 [
    set heading random 360
    fd delta
    ]
  ]

end

;;update to make it the specific kind of link we need
to check_collisions

  ask algae [
    let max_size parenthood_size
    ;;got this form the GasLab Circular Particles collision test
    let s who
    ask other algae in-radius ((size + max_size) / 2) with [distance myself < (size + [size] of myself) / 2 ] [
      ;;compute overlap = sum(radii) - distance
      let str (size + [size] of (turtle s))  - (distance (turtle s))
      create-overlap-with (turtle s) [set strength str hide-link]
      set health health - algae_sensitivity


    ]
  ]

end


;;update so that
to fix_collisions


  ;;while there are still links
  while [count overlaps > 0] [
    output-print "in fix collisions"
    ;;get the turtles involved in the strongest link (most overlap)
    let m max [strength] of overlaps
    let conns (list)
    let curr -1
    ask overlaps with [strength = m] [
      set curr self
      set conns (list end1 end2)
    ]

    ;;sometimes they will randomly end up being at the exact same location, so we randomly move them
    ifelse ([xcor] of first conns = [xcor] of last conns and [ycor] of first conns = [ycor] of last conns) [
      ask first conns [set heading random 360 set health health - algae_sensitivity]
      ask last conns [set heading 180 + [heading] of first conns set health health - algae_sensitivity]
      ask curr [die]
    ]
    [
    ;;change the heading so they are pointed away from eachother
    ask first conns [
      if count my-symbios = 0 [ ;;if not linked to a mycelae (if it is, it can't move)
          set heading towards last conns
          set heading heading + 180
          fd ([strength] of curr) / 8
          set health health - algae_sensitivity
        ]
    ]
    ask last conns [
        if count my-symbios = 0 [ ;;if not linked to a mycelae (if it is, it can't move)
          set heading towards first conns
          set heading heading + 180
          fd ([strength] of curr) / 8
          set health health - algae_sensitivity
        ]
      ]
    ask curr [die] ;;asking the link to die
    ]
  ]

end

;;now the fungi-only ones
to-report grow_fungi [id]
  ;;get the parent half-size and heading
  let h [heading] of turtle id
  let len ([size] of turtle id) / 2

  ;;get the new heading
  let dir (h + (random-float turn_radius) - (turn_radius / 2))

  ;;calculate the new xcor and ycor of the child
  let new_x ([xcor] of turtle id) + (len * (sin (dir) + sin(h)))
  let new_y ([ycor] of turtle id) + (len * (cos (dir) + cos (h)))


  let who_child -1
  ;;make the child
  create-mycelae 1 [
    set shape "line"
    set size mycelae_size
    set heading dir
    set xcor new_x
    set ycor new_y
    set color red

    ;;this is an external variable
    set who_child who

  ]

  ;;make it a specific kind of link
  ask turtle id [create-stream-to turtle (who_child) [tie hide-link]]

  report who_child

end

to intercalary_grow [id]
  ;;make a child, adding it as a downstream of the original
  let child_id grow_fungi id

  ;;get a list of the downstreams and pick one to add growth to (pick a downstream agent, who starts that stream)
  ask turtle id [
    ;;only works if there are existing downstreams; if there aren't, we can't do intercalary
    if count my-out-streams > 0 [
      ask one-of my-out-streams with [[who] of end2 != child_id] [
        ask end2 [

          ;;get the values we need for the next calculation (this is basically copied from the TO GROW operation)
          let temp get-tip child_id
          let tip_x item 0 temp
          let tip_y item 1 temp
          let len ([size] of turtle child_id) / 2
          let h [heading] of turtle child_id
          let dir [heading] of self

          ;;find the xy corrdinates of where a new growth would be if it started at the growing tip of the child w the heading of the old downstream
          let new_x ([xcor] of turtle child_id) + (len * (sin (dir) + sin(h)))
          let new_y ([ycor] of turtle child_id) + (len * (cos (dir) + cos (h)))

          ;;set the xcor and ycor of the old downstream to be coming from the tip of the new intercalary growth
          set xcor new_x
          set ycor new_y

          ;;make a link/tie from the previous downstream to the new child
          create-stream-from turtle (child_id) [tie hide-link ]
        ]
      ;;remove the tie and the link between the parent and the previous downstream
      die
      ]

    ]

  ]


end

;; gets the tip of the mycelia of the agent
to-report get-tip [id]
  let h [heading] of turtle id
  let len ([size] of turtle id ) / 2
  let d_x (len * (sin h))
  let d_y (len * (cos h))
  let x [xcor] of turtle id + d_x
  let y [ycor] of turtle id + d_y
  report (list x y)

end

;;make the mycelae associate with nearby algae
to associate

  ask mycelae [
    let s who
    ask (algae) in-radius parenthood_size with [distance myself < (size) / 2 and count my-symbios = 0] [
      ;;compute overlap = sum(radii) - distance
      create-symbio-from (turtle s) [hide-link tie]
    ]

  ]
end

to nutrients
  ;;is it faster/easier to ask the mycelae to get nutrients, or to ask the algae to send nutrients?

  ask mycelae [
    ;;should alter to make this representative of actual chemical diffuson gradient
    let temp food
    ask algae in-radius parenthood_size with [distance myself < (size * 1.5) ] [
      set temp temp + 10 * (((size * 1.5) - distance myself) / parenthood_size) ;;assuming linear concentration gradient
    ]
    set food temp
  ]

end



to mycelial_diffusion

  ask mycelae with [food > 0][
    let sum_inverses 0
    ask stream-neighbors [
      ifelse food > 0 [
      set sum_inverses sum_inverses + (1 / food)
      ][set sum_inverses sum_inverses + 2]
    ]
    let temp mycelial_diffusion_const * food / (sum_inverses + (1 / food))
    set temp_food temp_food - temp * sum_inverses
    ask stream-neighbors [
      ifelse food > 0 [
      set temp_food temp_food + ((1 / food) * temp)
      ][set temp_food temp_food + (2 * temp)]
    ]
  ]
  ask mycelae [
    set food food + temp_food
    set temp_food 0
  ]

end

to mycelial_color
  ask mycelae [
    set color scale-color red food (min [food] of mycelae) (max [food] of mycelae)
  ]
end

to spread
  let mycs (list mycelae)
  let m max [food] of mycelae
  let vals map [turt -> [self] of turt] mycs
  let temp map [turt -> [food] of turt] mycs
  set temp first temp
  let probs map [f -> f / m] temp

  output-show prob



end



@#$#@#$#@
GRAPHICS-WINDOW
210
10
1011
820
-1
-1
0.9900125
1
10
1
1
1
0
1
1
1
-400
400
-400
400
1
1
1
ticks
30.0

SLIDER
17
25
189
58
turn_radius
turn_radius
0
180
50.0
1
1
NIL
HORIZONTAL

SLIDER
22
131
194
164
branching
branching
0
10
4.0
0.1
1
NIL
HORIZONTAL

SLIDER
23
188
195
221
apical
apical
0
100
89.0
1
1
NIL
HORIZONTAL

SLIDER
25
263
197
296
intercalary
intercalary
0
10
10.0
0.1
1
NIL
HORIZONTAL

BUTTON
21
356
84
389
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
120
360
183
393
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
28
318
200
351
algae_sensitivity
algae_sensitivity
0
100
29.0
1
1
NIL
HORIZONTAL

SLIDER
28
448
200
481
growth_rate
growth_rate
0
1
0.08
0.01
1
NIL
HORIZONTAL

SLIDER
12
520
193
553
mycelial_diffusion_const
mycelial_diffusion_const
0
1
0.5
0.1
1
NIL
HORIZONTAL

@#$#@#$#@
## WHAT IS IT?

This is a simluation of the basic symbiotic interactions that occur in lichen: the interaction between a fungi (mycobiont) and an algae/cyanobacteria (photobiont).

## HOW IT WORKS

There are two agent types: the algae and the mycelae (photo and mycobiont, respectively). 

### ALGAE
The algae have a parameter, HEALTH, which determines their growth rate and photosynthetic output. In the base model, the only thing that affects their health is the crowding around them; if the algal density in a place is too high, the population will suffer and die off. 

Healthy algae are able to produce more energy, which is then siphoned off to mycelae attached to them. Over time, algae will grow in size proportional to their health and the GROWTH_RATE paramter. Once the PARENTHOOD_SIZE has been reached, the algae will split into daughter cells, mimicking an aplanospore -- if it is associated with a mycelae. The rationale behind this is that the aplanospore membrane requires agitation to break, and the mycelae infiltrate the membrane in real lichen. 

The algae will also wiggle around randomly in step sizes determined by the DELTA parameter, unless they are attached to mycelae. 

Sometimes algae will bump into each other. If this happens, they will move away from each other. If this causes new collisions, they will be resolved at the next tick. These collisions are also what determines the overcrowding that effects health; the more collisions, the less healthy the algae. Their sensitivity to voercrowding is determined by the ALGAE_SENSITIVITY parameter.

### MYCELAE

Mycelae spread around the space in lines, which are tied to each other and which send nutrients along their path. Mycelae can grow in three ways: apical, intercalary, or branching. Apical is where the tip-most cell of the hyphae will produce a daughter cell. Intercalary is when non-apical growth occurs to elongate an existing hyphal midsection. Branching is pretty self-explanatory, and can occur either apically or within the rest of the hyphae.

Mycelae will associate with algae they physically interact with, and they will attach to them and drag them along should intercalary growth occur. 

Associating with algae provides the mycelae with nutrients. Nutrients disperse through the mycelae over time. More nutrients trigger greater growth probability for a particular.

Nutrient dispersal:
Ask each mycelae, then ask each particle to pick to stay, go R, or go L. 


## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.2.2
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
