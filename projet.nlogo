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
  last-values-unemployement
  last-values-vacancy
  number-of-step-remembered ; nombre de pas pris en compte dans le calcul de la convergence
  convergence-margin ; marge de movement possibles en dessous de laquelle on considère que le système a convergé


]
breed [persons person]
breed [companies company]
breed [matching matching-agent]

persons-own [skills location salary reference_productivity employed employer]
companies-own [skills location salary job_filled employee]



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                       SETUP SINGLE SIMULATION                        ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to setup
  clear-all

  setup-globals
  setup-patches
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
  set convergence False
  set last-values-unemployement []
  set last-values-vacancy []
  set number-of-step-remembered 10 ; on calcule la convergence sur les 10 derniers pas de temps
  set convergence-margin 0.05 ; on fixe la marge à 5% quand les valeurs considérées varient de moins de 5 % sur les 10 derniers pas de temps, on considère que le système a convergé
end


; procédure d'affichage des différentes LOCATION sur le fond de l'écran de modélisation, par des bandes horizontales
; TODO peut-être l'améliorer, ça pose problème avec un grand nombre de zones
to setup-patches
  ask patches [
    let size-of-zones round ( (2 * max-pycor + 1) / number_of_locations_possibles )
    let a floor ((pycor - min-pycor) / size-of-zones)
    let b remainder a 2
   if b = 1 [set pcolor 1]
  ]
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

; procédure qui fixe au hasard les valeurs de compétences, lieu et salaires pour chaque agent (PERSON et COMPANY)
to set-random-skills-location-salary
  set skills (list random 2 random 2 random 2 random 2 random 2)
  set location random number_of_locations_possibles
  set salary minimum_salary + random (maximum_salary - minimum_salary)
end

; procédure qui fixe la valeur de référence de la productivité de l'employé au hasard selon une loi normale (pour le pas avoir de valeurs trop extrèmes)
to set-productivity
  set reference_productivity random-normal 0.7 0.3
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

  if ticks >= timeout or convergence [stop]

    agents-matching
    update-jobs

    compute-values
    update-convergence

  tick
end

; procédure de matching
; l'agent MATCHING va considérer à chaque tour au maximum number_of_pairs_considered et calculer la similarité entre l'entreprise et le condidat et déclencher la procédure d'embauche le cas échéant
to agents-matching
  ask matching [
    let number_of_matches min (list number_of_pairs_considered
                                  count persons with [not employed]
                                  count companies with [not job_filled])
    let random-person nobody
    let random-company nobody
    repeat number_of_matches [
      set random-person one-of persons with [not employed]
      set random-company one-of companies with [not job_filled]
      if compare random-person random-company [
        hiring_procedure random-person random-company
      ]
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
  report min List 1 similarity
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
  report min List 1 similarity
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
; elle renvoie le même résultat pour les agents PERSON et les agents COMPANY
; on veut que les salaires soient le plus proche possible : si le salaire proposé est trop élevé par rapport aux attentes de l'employé, c'est mauvais pour la similarité de celui-ci
to-report compute-similarity_salary [salary1 salary2]
  let max_salary max List salary1 salary2
  let min_salary min List salary1 salary2
  report 1 - (max_salary - min_salary) / max_salary
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
;;                         COMPUTING PROCEDURES                         ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to compute-values
  set unemployement_level count persons with [not employed]
  set vacancy_level count companies with [not job_filled]
  set unemployement_rate unemployement_level / labor_force
  set vacancy_rate vacancy_level / labor_force
  updates-last-values
end

; procédure qui met à jour les lists last-values-unemployement et last-values-vacancy qui gardent en mémoire les 10 dernières valeurs de unemployement_rate et vacancy_rate respectivement
to updates-last-values
  ifelse ticks < number-of-step-remembered [
    set last-values-unemployement lput unemployement_rate last-values-unemployement
    set last-values-vacancy lput vacancy_rate last-values-vacancy
  ]
  [
    set last-values-unemployement but-first last-values-unemployement
    set last-values-unemployement lput unemployement_rate last-values-unemployement
    set last-values-vacancy but-first last-values-vacancy
    set last-values-vacancy lput vacancy_rate last-values-vacancy
  ]
end

; procédure que surveille la convergence d'un système et met à jour la valeur du bolléen CONVERGENCE le cas échéant
; on surveille l'évolution des valeurs unemployement_rate et vacancy_rate : si elle n'ont pas variée de plus de 5% sur les 10 derniers steps, on considère que le système a convergé
; évolutions futures : améliorer ce point et rendre cela plus souple
to update-convergence
  if ticks > 500 [ ; on laisse un certain temps pour que la convergence se fasse
    let variation-unemployement (max last-values-unemployement - min last-values-unemployement) / mean last-values-unemployement
    let variation-vacancy (max last-values-vacancy - min last-values-vacancy) / mean last-values-vacancy
    if variation-unemployement < convergence-margin and variation-vacancy < convergence-margin [
      set convergence True;
    ]
  ]
end




;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                            BEVERIDGE CURVE                           ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to generate-simulations-BC
 clear-all

  set-current-plot "beveridge_curve"
  set-current-plot-pen "pen-0"
  set-plot-pen-mode 2

  show "-------------------------------------------------"
  show "              Début des simulations"
  show "-------------------------------------------------"
  ;; valeurs intiales de U
  foreach [100 200 300 400] [
    let initialU ?
    ;; valeurs intiales de V
    foreach [100 200 300 400] [
      let initialV ?

      show "simulation actuelle : u et v sont respectivement :"
      show initialU
      show initialV
      setup-simulations initialU initialV
      ;while [not convergence or ticks < timeout] [
      repeat timeout [
        go
      ]
      show "simulation finie : a convergé au bout de :"
      show ticks
      show "unemployement_rate vacancy_rate obtenus sont respectivement :"
      show unemployement_rate
      show vacancy_rate
      show "-------------------------------------------------"
      plotxy unemployement_rate vacancy_rate
    ]
  ]
end

to setup-simulations [initialU initialV]

  clear-turtles
  clear-patches
  reset-ticks

  setup-globals
  setup-patches
  setup-matching-agent
  setup-persons
  setup-companies
  set number_of_persons initialU
  set number_of_companies initialV


end
