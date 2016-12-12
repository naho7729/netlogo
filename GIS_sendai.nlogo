extensions [ gis ]

globals [ road-dataset node1-dataset node2-dataset hsp1-dataset
          center-x center-y Start Goal ]
breed [ nodes node ]
nodes-own [ to-node1 to-node2 to-node3 to-node4 node-cost previous-node kind ]
links-own [ link-cost ]

breed [ victims victim ]          victims-own [ location triage ]
breed [ resources resource ]      resources-own [ location ]
breed [ ambulances ambulance ]    ambulances-own [ location move? a-route ]
breed [ firemen fireman ]         firemen-own [ location move? f-route ]
breed [ soldiers soldier ]        soldiers-own [ location ]

to setup
  clear-all
  reset-ticks
  ask patches [ set pcolor white ]
  set road-dataset gis:load-dataset "LineRoadNetwork/Sendai_LineRoadNetwork_WGS84.shp"
  set node1-dataset gis:load-dataset "Sendai_node/Sendai_node_1.shp"
  set node2-dataset gis:load-dataset "Sendai_node/Sendai_node_2.shp"
  set hsp1-dataset gis:load-dataset "Sendai_HSP/Sendai_PMH_Opt1.shp"
  draw
end
to draw
  clear-drawing
  setup-world-envelope
  gis:set-drawing-color gray gis:draw road-dataset 1.0
end
to setup-world-envelope
  gis:set-world-envelope gis:envelope-of road-dataset
  let world gis:world-envelope
  let x0 (item 0 world + item 1 world) / 2 + center-x
  let y0 (item 2 world + item 3 world) / 2 + center-y
  let w0 zoom * (item 1 world - item 0 world) / 2
  let h0 zoom * (item 3 world - item 2 world) / 2
  set world (list (x0 - w0) (x0 + w0) (y0 - h0) (y0 + h0))
  gis:set-world-envelope world
end

to-report meters-per-patch
  let x-meters-per-patch  precision (3785.923 / max-pxcor) 1
  let y-meters-per-patch precision (3213.946 / max-pycor) 1
  report list x-meters-per-patch y-meters-per-patch
end

to display-node
  clear-turtles
  let node1-feature gis:feature-list-of node1-dataset
  foreach node1-feature [ create-nodes 1
    [ set kind "campas" set color blue set shape "dot" set size 1
      let l gis:location-of first first gis:vertex-lists-of ?
      setxy item 0 l item 1 l ] ]

  let hsp1-feature gis:feature-list-of hsp1-dataset
  foreach hsp1-feature [ create-nodes 1
    [ set kind "hospital" set color orange set shape "dot" set size 1
      let l gis:location-of first first gis:vertex-lists-of ?
      setxy item 0 l item 1 l ] ]

  let node2-feature gis:feature-list-of node2-dataset
  foreach node2-feature [ create-nodes 1
    [ set kind "point" set color cyan set shape "dot" set size 1
      set to-node1 gis:property-value ? "NODE1"
      set to-node2 gis:property-value ? "NODE2"
      set to-node3 gis:property-value ? "NODE3"
      set to-node4 gis:property-value ? "NODE4"
      let l gis:location-of first first gis:vertex-lists-of ?
      setxy item 0 l item 1 l ] ]
end

to-report Dijkstra
  let route []
  ask nodes [ set node-cost 999999 ]
  ask node Start [ set node-cost 0 ]

  let link-list sort links
  foreach link-list [ ask ? [ set link-cost link-length ] ]
  let current Start
  let current-node-cost 0
  let unvisited sort nodes
  set unvisited remove node Start unvisited

  while [ not empty? unvisited and current != Goal ]
        [ foreach unvisited
          [ let neighbor ?
            if is-link? link current [who] of neighbor
            [ let c 0
              ask link current [who] of neighbor [set c link-cost]
              ask neighbor [ if (c + current-node-cost) < node-cost
                [ set node-cost (c + current-node-cost)
                  set previous-node current ]
                ] ] ]
          set unvisited remove node current unvisited
          set current [who] of min-one-of turtle-set unvisited [node-cost]
          set current-node-cost [node-cost] of node current ]

  set route lput Goal route
  let k Goal
  while [ k != Start ]
        [ ask node k [ set route fput previous-node route ] set k item 0 route ]
  set route remove item 0 route route
  report route
end

;; create victims, on randam node, with triage
;; create ambulances, on node 14,
;; create firemen, on node 0
to Disaster
  let p-list sort-on [who] nodes with [ kind = "point" ]

  create-victims 20 [ set location one-of p-list move-to location
                      set triage one-of [ 0 1 2 3 ] ]
  create-ambulances 5 [ set location node 14 move-to location
                        let search-done? false ]

  create-firemen 2 [ set location node 0 move-to location ]
end

;; select victim
to go
  if any? ambulances-on node 14 [ command-a1 ]
  ask ambulances [ move-ambulance ]

  if any? firemen-on node 0 [ command-f1 ]
  ask firemen [move-fireman]

  tick
end

;; ambulance who have a-route can move
;; if he can't move, to command-2
to move-ambulance
    if empty? a-route [ set move? false ]
    ifelse move? [
      let new-location (node item 0 a-route)
      let distance-from-location distance new-location
      ifelse who * 0.0005 < distance-from-location
        [face new-location jump who * 0.0005]
        [face new-location move-to new-location
        set location new-location
        set a-route remove item 0 a-route a-route ]
    ] [ command-2 ]
end
to move-fireman
    if empty? f-route [ set move? false ]
    ifelse move? [
      let new-location (node item 0 f-route)
      let distance-from-location distance new-location
      ifelse who * 0.0005 < distance-from-location
        [face new-location jump who * 0.0005]
        [face new-location move-to new-location
        set location new-location
        set f-route remove item 0 f-route f-route ]
    ] [ command-2 ]
end

;; ambulance list a on node 14, number n
;; victim list v on noed 14, location list v-location
to command-a1
  let a sort ambulances-on node 14
  let n length a
  let v sort n-of n victims
  let v-location []
  foreach v [ ask ? [ set v-location lput [who] of [location] of ? v-location ] ]
  foreach a [ ask ? [ set Start 14 set Goal (item (position ? a) v-location) set a-route Dijkstra set move? true ] ]
end
to command-f1
  let f sort firemen-on node 0
  let n length f
  let v sort n-of n victims with [ triage = 2 or triage = 1 ]
  let v-location []
  foreach v [ ask ? [ set v-location lput [who] of [location] of ? v-location ] ]
  foreach f [ ask ? [ set Start 0 set Goal (item (position ? f) v-location) set f-route Dijkstra set move? true show f-route] ]
end
to command-2
  ask victims [ if triage = 3 [ create-link-to one-of ambulances-on self [tie] ] ]
end
@#$#@#$#@
GRAPHICS-WINDOW
152
10
1242
761
-1
-1
12.0
1
8
1
1
1
0
0
0
1
0
89
0
59
1
1
1
ticks
30.0

BUTTON
9
10
146
43
setup
ca setup\nset center-x -0.0132\nset center-y -0.025\nset zoom 0.27\ndraw display-node\nask nodes [ set label who set label-color black ]\nlet node-list sort nodes\nforeach node-list [\n  ask ? [ if  to-node1 > 0 [\n  create-link-with node to-node1 ]\n  if  to-node2 > 0 [\n  create-link-with node to-node2 ]\n  if  to-node3 > 0 [\n  create-link-with node to-node3 ]\n  if  to-node4 > 0 [\n  create-link-with node to-node4 ]]]\n  ask links [hide-link]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
9
134
146
167
zoom
zoom
0.01
1.2
0.27
0.01
1
NIL
HORIZONTAL

BUTTON
9
48
77
81
Disaster
Disaster\nask ambulances [set shape \"car-2\" set color green]\nask firemen [set shape \"car-2\" set color red]\n
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
81
48
146
81
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
0

MONITOR
9
198
86
243
ambulances
count ambulances
17
1
11

MONITOR
9
300
64
345
victims
count victims
17
1
11

MONITOR
9
249
69
294
firemen
count firemen
17
1
11

MONITOR
76
301
144
346
resources
count resources
17
1
11

MONITOR
5
650
140
695
meter-per-patch
meters-per-patch
17
1
11

@#$#@#$#@
## WHAT IS IT?

This model was built to test and demonstrate the functionality of the GIS NetLogo extension.

## HOW IT WORKS

This model loads four different GIS datasets: a point file of world cities, a polyline file of world rivers, a polygon file of countries, and a raster file of surface elevation. It provides a collection of different ways to display and query the data, to demonstrate the capabilities of the GIS extension.

## HOW TO USE IT

Select a map projection from the projection menu, then click the setup button. You can then click on any of the other buttons to display data. See the code tab for specific information about how the different buttons work.

## THINGS TO TRY

Most of the commands in the Code tab can be easily modified to display slightly different information. For example, you could modify `display-cities` to label cities with their population instead of their name. Or you could modify `highlight-large-cities` to highlight small cities instead, by replacing `gis:find-greater-than` with `gis:find-less-than`.

## EXTENDING THE MODEL

This model doesn't do anything particularly interesting, but you can easily copy some of the code from the Code tab into a new model that uses your own data, or does something interesting with the included data. See the other GIS code example, GIS Gradient Example, for an example of this technique.

## RELATED MODELS

GIS Gradient Example provides another example of how to use the GIS extension.

## CREDITS AND REFERENCES
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

car-2
true
0
Rectangle -7500403 true true 105 60 195 240
Rectangle -7500403 true true 90 45 210 255

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

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270

@#$#@#$#@
NetLogo 5.3.1
@#$#@#$#@
setup
display-cities
display-countries
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
