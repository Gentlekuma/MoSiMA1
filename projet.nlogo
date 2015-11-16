globals [ ; EN COMMENTAIRES : ceux qui sont définis sur l'interface TODO : changer les noms des variables et les redéfinir dans setup-globals
  color-person-employed
  color-person-unemployed
  color-company-filled-job
  color-company-vacant-job
  ;number_of_persons
  ;number_of_companies
  ;number_of_pairs_considered
  ;minimum_salary
  ;maximum_salary
  ;number_of_locations_possibles
  ;unexpected_company_motivation
  ;unexpected_worker_motivation
  ;maximum_productivity_fluctuation
  ;unexpected_firing
  minimum_similarity_required
  minimum_productivity_required
  labor_force
  unemployement_level
  unemployement_rate
  vacancy_level
  vacancy_rate
  convergence
    
]  ;;
breed [persons person]
breed [companies company]
breed [matching matching-agent]

persons-own [skills location salary reference_productivity employed employer]
companies-own [skills location salary job_filled employee]



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                 SETUP                                ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to setup
  clear-all
  
  setup-globals
  setup-matching-agent
  setup-persons
  setup-companies
  
  reset-ticks
end

; procédure d'initialisation des variables globales
to setup-globals
  set color-person-employed 67
  set color-person-unemployed 17
  set color-company-filled-job 63
  set color-company-vacant-job 17
  set minimum_similarity_required matching_quality_threshold
  set minimum_productivity_required firing_quality_threshold
  set labor_force number_of_persons ; on considère pour le moment comme agents que les travailleurs dans un système fermé
  set convergence False;
end

; procédure d'initialisation de l'agent MATCHING
to setup-matching-agent
  set-default-shape matching "square 2"
  create-matching 1 [
    set color white
    set size 2
    setxy 0 0
  ]
end

; procédure d'initialisation des agents PERSON
to setup-persons
  set-default-shape persons "person"
  set-default-shape companies "house"
  create-persons number_of_persons [
    set color color-person-unemployed
    set size 2
    set-random-skills-location-salary
    set-productivity
    set employed False
    set employer nobody
    set-xy
  ]
end

; procédure d'initialisation des agents COMPANY
to setup-companies  
  create-companies number_of_companies [
    set color color-company-vacant-job
    set size 2
    set-random-skills-location-salary
    set job_filled False
    set employee nobody
    set-xy
  ]
end

; procédure qui fixe les valeurs de compétences, lieu et salaires pour chaque agent (PERSON et COMPANY)
to set-random-skills-location-salary
  set skills (list random 2 random 2 random 2 random 2 random 2)
  set location random number_of_locations_possibles
  set salary minimum_salary + random (maximum_salary - minimum_salary)
end

; procédure qui fixe la valeur de référence de la productivité de l'employé au hasard selon une loi normale (pour le pas avoir de valeurs trop extrèmes)
to set-productivity
  set reference_productivity random-normal 0.8 0.2
end

; procédure que dispose les agents (PERSON et COMPANY) en fonction de leur attribut LOCATION
; on considère les différents lieux comme des bandes horizontales sur la zone d'affichage
to set-xy
  let x random-pxcor
  let y min-pycor + location * (max-pycor - min-pycor) / number_of_locations_possibles + random (max-pycor - min-pycor)/ number_of_locations_possibles  
  setxy x + 0.25 y + 0.25
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                 GO                                   ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; procédure de base, qui se déroule à chaque tour
; pour le moment la notion de convergence est simpliste : si l'agent MATCHING n'a pas de paire à considérer, il considère que le système a convergé
to go
  
  if ticks >= timeout  or convergence [stop]
  
    agents-matching
    update-jobs
  
    compute-values
  
  tick
end

; procédure de matching
; l'agent MATCHING va considérer à chaque tour au maximum number_of_pairs_considered et calculer la similarité entre l'entreprise et le condidat et déclencher la procédure d'embauche le cas échéant
to agents-matching
  ask matching [
    let number_of_loops min (list number_of_pairs_considered
                                  count persons with [not employed]
                                  count companies with [not job_filled])
    let random-person nobody
    let random-company nobody
    repeat number_of_loops [
      set random-person one-of persons with [not employed]
      set random-company one-of companies with [not job_filled]    
      if compare random-person random-company [
        hiring_procedure random-person random-company
      ]
    ]
    if number_of_loops = 0 [
      set convergence True
    ]
  ]
end

; procédure qui a chaque tour, décide des productivité des employé et de si ils se font licencier ou non
; on considère le paramètre unexpected_firing comme une augmentation des attentes de l'employeur qui a une probabilité d'arriver de exceptional_event_probability
to update-jobs
  ask persons [
    if employed [
      let productivity compute-productivity
      if ( random-float 1 < exceptional_event_probability) [
        set productivity productivity - unexpected_firing
      ]
      if productivity < minimum_productivity_required [
        firing_procedure [employee] of employer employer
      ]
    ]
  ]
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                         MATCHING PROCEDURES                          ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; fonction qui se charge de comparer les exigences d'une PERSON et d'une COMPANY
; renvoie un bolléen : si les 2 agents se correspondent ou pas
to-report compare [person company]
  let similarity-person compute-similarity-person person company
  let similarity-company compute-similarity-company person company
  let similarity mean List similarity-person similarity-company
  report similarity >= minimum_similarity_required
end

; fonction qui calcule la valeur de la similarité du point de vue de l'employé
; renvoie un nombre entre 0 et 1
;actuellement les deux fonctions sont semblables, comme le veut l'article, mais il sera possible de les différencier pour améliorer le modèle par la suite
; on considère que la motivation execptionnelle intervient à ce niveau pour faire augmenter les chances que la personne accepte ce travail
; elle a une probabilité d'arriver de exceptional_event_probability
to-report compute-similarity-person [person company]
  let similarity_skills compute-similarity_skills [skills] of person [skills] of company
  let similarity_location compute-similarity_location [location] of person [location] of company
  let similarity_salary compute-similarity_salary [salary] of person [salary] of company
  let similarity (similarity_skills + similarity_location + similarity_salary) / 3
  if (random-float 1 < exceptional_event_probability) [
    set similarity similarity + unexpected_worker_motivation
  ]
  report similarity
end

; fonction qui calcule la valeur de la similarité du point de vue de l'entreprise
; renvoie un nombre entre 0 et 1
;actuellement les deux fonctions sont semblables, comme le veut l'article, mais il sera possible de les différencier pour améliorer le modèle par la suite
; on considère que la motivation execptionnelle intervient à ce niveau pour faire augmenter les chances que l'entreprise accepte cet employé
; elle a une probabilité d'arriver de exceptional_event_probability
to-report compute-similarity-company [person company]
  let similarity_skills compute-similarity_skills [skills] of company [skills] of person
  let similarity_location compute-similarity_location [location] of company [location] of person
  let similarity_salary compute-similarity_salary [salary] of company [salary] of person
  let similarity (similarity_skills + similarity_location + similarity_salary) / 3
  if (random-float 1 < exceptional_event_probability) [
    set similarity similarity + unexpected_company_motivation
  ]
  report similarity
end

; fonction qui calcule la similarité entre les compétences attendus par l'entreprise et celles possédées par le candidat
; renvoie un nombre entre 0 et 1
; elle renvoie le même résultat pour les agents PERSON et les agents COMPANY
to-report compute-similarity_skills [skills1 skills2]
  let counting 0
  (foreach skills1 skills2 [
    if ?1 = ?2 [
       set counting counting + 1 
    ]
  ])
  report counting / length skills1
  
end

; fonction qui calcule la similarité entre les lieux de l'entreprise et du candidat
; renvoie un nombre entre 0 et 1
; elle renvoie le même résultat pour les agents PERSON et les agents COMPANY
to-report compute-similarity_location [location1 location2]
  ifelse location1 = location2
  [report 1]
  [report 0]
end

; fonction qui retourne la similarité entre les salaires
; renvoie un nombre entre 0 et 1
; en fonction de l'ordre dans lequel on passe les paramètres, le résultat n'est pas le même (le premier salaire étant la valeur de référence)
to-report compute-similarity_salary [salary1 salary2]  
  report 1 - abs (salary1 - salary2) / salary1
  
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                             PRODUCTIVITY                             ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; fonction qui calcule la productivité d'une PERSON à chaque tour, en se basant sur la valeur de référence, propre à chaque agent
; renvoie un nombre entre 0 et 1
; il s'agit d'une valeur comprise entre + ou - maximum_productivity_fluctuation de la valeur de référence de productivité de l'agent
to-report compute-productivity
  let productivity reference_productivity - maximum_productivity_fluctuation + random-float ( 2 * maximum_productivity_fluctuation)
  if productivity < 0 [
    set productivity 0
  ]
  if productivity > 1 [
    set productivity 1
  ]
  report productivity
end



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                     HIRING AND FIRING PROCEDURES                     ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; procédure d'embauche
; on met à jour les attributs des agents
to hiring_procedure [person company] 
  ask person [
    set color color-person-employed
    set employed True  
    set employer company 
    create-link-with company 
  ]
  ask company [
    set color color-company-filled-job
    set job_filled True  
    set employee person
  ]
end

; procédure de licenciement
; on met à jour les attributs des agents
to firing_procedure [person company]
  ask person [
    set color color-person-unemployed
    set employed False  
    set employer nobody  
    ask my-links [die]
  ]
  ask company [
    set color color-company-vacant-job
    set job_filled False  
    set employee nobody
  ]
end



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                            PRINTING CURVES                           ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to compute-values
  set unemployement_level count persons with [not employed]
  set vacancy_level count companies with [not job_filled] 
  set unemployement_rate unemployement_level / labor_force
  set vacancy_rate vacancy_level / labor_force
end
@#$#@#$#@
GRAPHICS-WINDOW
502
10
971
500
25
25
9.0
1
14
1
1
1
0
1
1
1
-25
25
-25
25
1
1
1
ticks
30.0

BUTTON
8
28
77
61
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
90
28
157
61
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

TEXTBOX
26
273
177
291
Matching
11
0.0
0

SLIDER
162
28
334
61
timeout
timeout
100
5000
1000
100
1
NIL
HORIZONTAL

SLIDER
17
106
189
139
number_of_persons
number_of_persons
10
500
60
1
1
NIL
HORIZONTAL

SLIDER
17
149
191
182
number_of_companies
number_of_companies
10
500
50
1
1
NIL
HORIZONTAL

SLIDER
21
293
231
326
number_of_pairs_considered
number_of_pairs_considered
0
100
5
1
1
NIL
HORIZONTAL

SLIDER
245
144
417
177
minimum_salary
minimum_salary
500
1500
1500
1
1
NIL
HORIZONTAL

SLIDER
246
101
418
134
maximum_salary
maximum_salary
2000
10000
2153
1
1
NIL
HORIZONTAL

SLIDER
245
185
432
218
number_of_locations_possibles
number_of_locations_possibles
1
10
3
1
1
NIL
HORIZONTAL

TEXTBOX
248
80
402
98
Personal preferences
11
0.0
1

SLIDER
246
294
449
327
matching_quality_threshold
matching_quality_threshold
0
1
0.5
0.1
1
NIL
HORIZONTAL

TEXTBOX
22
83
172
101
System settings
11
0.0
1

TEXTBOX
25
392
175
410
Productivity
11
0.0
1

SLIDER
20
411
200
444
firing_quality_threshold
firing_quality_threshold
0
1
0.5
0.1
1
NIL
HORIZONTAL

SLIDER
20
452
202
485
unexpected_firing
unexpected_firing
0
1
0.1
0.1
1
NIL
HORIZONTAL

SLIDER
18
331
231
364
unexpected_company_motivation
unexpected_company_motivation
0
1
0.1
0.1
1
NIL
HORIZONTAL

SLIDER
246
333
449
366
unexpected_worker_motivation
unexpected_worker_motivation
0
1
0.1
0.1
1
NIL
HORIZONTAL

PLOT
1016
57
1216
207
unemployement and vacancy rate
time
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"unemployement_rate" 1.0 0 -955883 true "" "plot unemployement_rate"
"vacancy_rate" 1.0 0 -14454117 true "" "plot vacancy_rate"

MONITOR
1008
239
1139
284
unemployement_rate
unemployement_rate
17
1
11

MONITOR
1165
237
1298
282
vacancy_rate
vacancy_rate
17
1
11

PLOT
1084
342
1284
492
courbe de Beveridge
unemployement_rate
vacancy_rate
0.0
1.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 2 -16777216 true "" "plotxy unemployement_rate vacancy_rate"

SLIDER
228
410
432
443
maximum_productivity_fluctuation
maximum_productivity_fluctuation
0
0.5
0.2
0.1
1
NIL
HORIZONTAL

SLIDER
8
205
191
238
exceptional_event_probability
exceptional_event_probability
0
1
0.1
0.1
1
NIL
HORIZONTAL

@#$#@#$#@
## WHAT IS IT?


## HOW IT WORKS


## HOW TO USE IT

Parameters:


## THINGS TO NOTICE


## THINGS TO TRY


## EXTENDING THE MODEL


## NETLOGO FEATURES


## RELATED MODELS


## CREDITS AND REFERENCES


## HOW TO CITE


## COPYRIGHT AND LICENSE
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
NetLogo 5.2.0
@#$#@#$#@
setup
set grass? true
repeat 75 [ go ]
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
