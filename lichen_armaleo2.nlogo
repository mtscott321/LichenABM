extensions [ rnd array]

breed [algae alga]
algae-own [health]
breed [hyphae hypha]
hyphae-own [blue_ temp_blue red_ temp_red food temp_food] ;;red is upstream, blue is downstream. They have underscores bc the colors are keywords in NetLogo

directed-link-breed [streams stream] ;;hyphae stream link
directed-link-breed [symbios symbio] ;;hyphae to aplanospore link
undirected-link-breed [overlaps overlap]
overlaps-own [strength]

globals [hyphae_size
  algae_starting_size
  algae_sensitivity
  parenthood_size
  delta
  signal_decay_const
  hyphal_growth_threshold
]

to setup
  ca
  reset-ticks

  ;;setting all the kinda boring globals that I dont' want to make sliders
  set algae_starting_size 5
  set parenthood_size 10
  set delta 1 ;;how much to stochastically wiggle
  set hyphae_size 10
  set algae_sensitivity 90
  set signal_decay_const 0.7
  set hyphal_growth_threshold 1

  ;;creating the starting agents. This will eventually depend on the way we want to start (random, isidia, soredia, etc)
  create-hyphae 10 [set shape "line" set color red set size hyphae_size set food 1]

  create-algae 1 [set shape "circle" set color green set size algae_starting_size set health 100 ]

end

to go
  ;;decay of signalling proteins (is this necessary?)
  ask hyphae [
    set red_ red_ * signal_decay_const
    set blue_ blue_ * signal_decay_const
  ]


  ;;algae growth
  ;;if the aplanospore is healthy
  ask algae [
    if random 100 < health [
      grow_algae who ;if this algae is healthy, grow it
    ]
    if health <= 0 [die]
    wiggle who
  ]
  ask overlaps [die] ;;overlaps are existing links from previous round that we want to redetermine
  check_collisions
  fix_collisions

  ;;this is where I would put a function where the algae send signals so the hyphae can move towards them

  ;;hyphae that are associated w algae send signals to red_ and blue_stream neighbors
  hyphae_signals

  ;;hyphae send a portion of their signals to adjacents
  hyphae_diffuse_signals

  ;;hyphae grow
  ifelse growth_pattern = "a" [
    hyphae_grow_a
  ] [hyphae_grow_b]

  ;;make the symbiotic bonds!
  associate

  ;;color the hyphal cells
  hyphal_color

  tick


end

;;grow and split algae
to grow_algae [id]
  ask turtle id [
    if size < parenthood_size [set size size + algal_growth_rate]
    if size >= parenthood_size and count my-symbios > 0 [ ;aplanospore only gets punctured if there are hyphae connected
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

;;red_date to make it the specific kind of link we need
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

;;based on the Gas Lab collisions
to fix_collisions

  ;;while there are still links
  while [count overlaps > 0] [
    ;;get the turtles involved in the strongest link (most overlap)
    let m max [strength] of overlaps
    let conns (list)
    let curr -1
    ask overlaps with [strength = m] [
      set curr self
      set conns (list end1 end2)
    ]

    ;;sometimes they will randomly end red_ being at the exact same location, so we randomly move them
    ifelse ([xcor] of first conns = [xcor] of last conns and [ycor] of first conns = [ycor] of last conns) [
      ask first conns [set heading random 360 set health health - algae_sensitivity]
      ask last conns [set heading 180 + [heading] of first conns set health health - algae_sensitivity]
      ask curr [die]
    ]
    [
    ;;change the heading so they are pointed away from eachother
    ask first conns [
      if count my-symbios = 0 [ ;;if not linked to a hyphae (if it is, it can't move)
          set heading towards last conns
          set heading heading + 180
          fd ([strength] of curr) / 8
          set health health - algae_sensitivity
        ]
    ]
    ask last conns [
        if count my-symbios = 0 [ ;;if not linked to a hyphae (if it is, it can't move)
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

to hyphae_signals
  ;;algae trigger chemical release in associated cells
;  ask hyphae with [count my-symbios > 0] [
;    set blue_ blue_ + 1
;    set red_ red_ + 1
;  ]
  let temp 0
  ask hyphae [
    ask algae in-radius parenthood_size with [distance myself < (size * 1.5)] [
      set temp (((size * 1.5) - distance myself) / parenthood_size)
    ]
    set red_ red_ + temp
    set blue_ blue_ + temp
  ]

  ask hyphae [
    set temp food
    ask algae in-radius parenthood_size with [distance myself < (size * 1.5) ] [
      set temp temp + 10 * (((size * 1.5) - distance myself) / parenthood_size) ;;assuming linear concentration gradient
    ]
    set temp temp * signal_decay_const ;;cost for living in each tick

    set food temp
  ]
end

to hyphae_diffuse_signals
  ;;blue_ gets sent further blue_stream
  ask hyphae with [blue_ > 0] [
    let d blue_
    ask my-out-streams [
      ask end2 [
        set temp_blue d * mycelial_diffusion_const
      ]
    ]
    set blue_ blue_ * (1 - mycelial_diffusion_const)
  ]
  ;;red_ gets sent further red_stream
  ask hyphae with [red_ > 0] [
    let u red_
    ask my-in-streams [
      ask end1 [
        set temp_red u * mycelial_diffusion_const
      ]
    ]
    set red_ red_ * (1 - mycelial_diffusion_const)
  ]
  ask hyphae [
    set red_ red_ + temp_red
    set blue_ blue_ + temp_blue
    set temp_red 0
    set temp_blue 0
  ]
end

;;here are the two main functions (grow branch and grow nonbranch) that all the growth form functions will use

to grow_non_branch
  let intercalary? false
  if count my-out-streams > 0 [set intercalary? true]
  let child_id grow
  ;;if intercalary (the cell is nonapical), we need to move the downstream cells to accomodate for the new growth
  if intercalary? [
    ;;getting the previous downstreams so I can move them to be after the new child
    ask my-out-streams with [[who] of end2 != child_id] [
      ask end2[
        let len ([size] of turtle child_id) / 2
        set xcor ([xcor] of turtle child_id) + len * (sin (heading) + sin ([heading] of turtle child_id))
        set ycor ([ycor] of turtle child_id) + len * (cos (heading) + cos ([heading] of turtle child_id))
        create-stream-from turtle child_id [tie hide-link]
      ]
      die
    ]
  ]

end

;;ideally, update to include Goodenough's data on intercalary vs. apical branching angles
to grow_branch
  ;;if apical, we need to grow twice; once to create a downstream, and another to create a branch
  if count my-out-streams = 0 [
    let trash grow
  ]
  let trash grow
end

;;just adds a downstream hyphal cell and returns its id
to-report grow
  let dir heading + (random-float turn_radius) - (turn_radius / 2)
  let new_x xcor + (size / 2) * (sin(dir) + sin(heading))
  let new_y ycor + (size / 2) * (cos(dir) + cos(heading))

  let who_child -1

  hatch-hyphae 1 [
    set heading dir
    set xcor new_x
    set ycor new_y
    ;;external variable -- saving the id so we can return it
    set who_child who
  ]

  create-stream-to turtle who_child [tie hide-link]

  report who_child

end

;;here are the functions that decide which hyphal cells will grow and in what way

;;each agent has a probability of growing, and for each agent we stochastically find if it will grow
;;then if it grows, we find if it will branch or not branch
to hyphae_grow_a
  ;;have to normalize all the values to do the probability stuff
  let norm 0
  ask hyphae [
    let apical_coeff 1
    if count my-out-streams = 0 [set apical_coeff apical_advantage] ;;only get the apical advantage coeff if apical
    set norm norm + branching_coeff * blue_ * apical_coeff + red_
  ]

  ;;if no one has any signals, then just grow one randomly.
  ifelse norm = 0 [
    ask one-of hyphae [
      ifelse random-float 10 < branching_coeff [
        grow_branch
      ] [grow_non_branch]
    ]
  ]
  [
    ask hyphae [
      let apical_coeff 1
      if count my-out-streams = 0 [set apical_coeff apical_advantage]
      let prob_grow (branching_coeff * blue_ * apical_coeff + red_) / norm

      ;;if we decide to grow
      if random-float 1 <= prob_grow [
        grow_branch
        ifelse random-float 1 <= ((branching_coeff * blue_ * apical_coeff) / prob_grow)[
        ][ grow_non_branch]
      ]
    ]
  ]
end

;;this one is based on lichen_advanced2, where growth is only based on the amount of food you have.
to hyphae_grow_b
  set hyphal_growth_threshold 0.99 * (max [red_ + blue_] of hyphae)
  let r_val max [red_ + blue_] of hyphae
  let mycs [who] of hyphae with [red_ + blue_ > hyphal_growth_threshold]
  if length mycs > 0 [
    let index 0
    while [index < length mycs] [
      ;;getting the id of this hyphae
      let id item index mycs
      ask turtle id [
        let apical_coeff 0
        if count my-out-streams = 0 [set apical_coeff apical_advantage]
        ;;if we randomly decide to grow
        if random-float r_val < red_ + blue_ + apical_advantage [
          ifelse random (r_val / branching_coeff) < blue_ [
          grow_branch
          ][grow_non_branch]
        ]
      ]
      set index index + 1
    ]
  ]
end

to associate
  ask hyphae [
    let temp who
    ask (algae) in-radius parenthood_size with [distance myself < (size) / 2 and count my-symbios = 0] [
      ;;compute overlap = sum(radii) - distance
      create-symbio-from (turtle temp) [hide-link tie]
    ]
  ]
end

to hyphal_color
  ask hyphae [
    ;set color scale-color red (red_ + blue_) (min [red_ + blue_] of hyphae) (max [red_ + blue_] of hyphae)
    set color scale-color red (red_) (min [red_ ] of hyphae) (max [red_ ] of hyphae)
  ]

end


@#$#@#$#@
GRAPHICS-WINDOW
210
10
1011
820
-1
-1
0.9
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
0
0
1
ticks
30.0

BUTTON
15
450
78
483
setup
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
125
450
188
483
go
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
15
405
187
438
algal_growth_rate
algal_growth_rate
0
1
0.08
0.01
1
NIL
HORIZONTAL

SLIDER
15
80
190
113
mycelial_diffusion_const
mycelial_diffusion_const
0
1
0.1
0.01
1
NIL
HORIZONTAL

SLIDER
15
130
190
163
apical_advantage
apical_advantage
0
1
0.5
0.01
1
NIL
HORIZONTAL

SLIDER
15
180
190
213
branching_coeff
branching_coeff
0
10
0.71
0.01
1
NIL
HORIZONTAL

TEXTBOX
15
30
165
55
Fungal Globals
16
0.0
1

TEXTBOX
20
355
170
390
Algal Globals
16
0.0
1

CHOOSER
15
270
153
315
growth_pattern
growth_pattern
"a" "b" "food-based"
0

SLIDER
15
225
190
258
turn_radius
turn_radius
0
180
152.0
1
1
NIL
HORIZONTAL

PLOT
5
490
205
640
Signalling Proteins
Tick
Average Value
0.0
1.0
0.0
1.0
true
false
"" ""
PENS
"red" 1.0 0 -2674135 true "" "if count hyphae > 0 [\nplot (sum [red_] of hyphae) / (count hyphae)\n]"
"blue" 1.0 0 -13345367 true "" "if count hyphae > 0 [\nplot (sum [blue_] of hyphae) / (count hyphae)\n]"

@#$#@#$#@
## WHAT IS IT?

This is a simluation of the basic symbiotic interactions that occur in lichen: the interaction between a fungi (mycobiont) and an algae/cyanobacteria (photobiont). The specific goal of this particular model is to show early development of the symbiotic interaction. In the interface, algae are round green cells, and mycelae are thin red lines.

Parameters **bolded** are ones which are able to be changed in the Interface tab. Some global paramters must be changed in the code tab, to avoid crowding and confusion -- and because all of the non-bolded parameters are unlikely to be seen in nature/don't affect much. 

## AGENTS

There are two agent types: the algae and the fungal mycelae (photo and mycobiont, respectively). These were chosen because they are the two primary symbionts in nearly all lichen, and it is thought that their interaction determines the physical shape of lichen.

The agent selection and subsequent interactions are justified by translating as well as possible the interactions explained in Armaleo 1991 ("Experimental Microbiology of Lichens: Mycelia Fragmentation, A Novel Growth Chamber, and the Origins of Thallus Differentiation", Symbiosis 11 163-177). Unless otherwise stated, all interactions and actions by the agents are derived from this paper. This section covers the properities, actions, and interactions of the agent types. All model inputs are discussed in this section, as all inputs are related to affecting agent operation (no environmental variables).




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
1
@#$#@#$#@
