% ===
% PREDICATS UTILITAIRES
% ===

% remove_res(ResidentID, List, NewList)
% Fonction: Supprime un element specifique d'une liste.
% Parametres: ResID: ID du resident, List: Liste initiale, NewList: Liste resultante
remove_res(_, [], []).
remove_res(X, [X|T], T) :- !.
remove_res(X, [H|T], [H|T2]) :- remove_res(X, T, T2).

% update_match(ProgramID, NewResList, MatchSet, NewMatchSet)
% Fonction: Met a jour la liste des residents d'un programme donne.
% Parametres: ProgID: ID du programme, NewRes: Nouvelle liste, MatchSet: Ensemble actuel, NewMatchSet: Nouvel ensemble
update_match(_, _, [], []).
update_match(ProgID, NewRes, [match(ProgID, _)|T], [match(ProgID, NewRes)|T]) :- !.
update_match(ProgID, NewRes, [H|T], [H|NewT]) :- update_match(ProgID, NewRes, T, NewT).

% sum_caps(CapacitiesList, TotalCapacity)
% Fonction: Calcule la somme totale des capacites disponibles dans une liste.
% Parametres: CapacitiesList: Liste des entiers, TotalCapacity: Somme calculee
sum_caps([], 0).
sum_caps([H|T], Total) :- sum_caps(T, Rest), Total is H + Rest.

% ===
% PREDICATS DE BASE
% ===

% rankInProgram(ResidentID, ProgramID, Rank)
% Fonction: Trouve le rang d'un resident dans la liste d'un programme.
% Parametres: Res: ID du resident, Prog: ID du programme, Rank: Rang trouve
rankInProgram(Res, Prog, Rank) :- 
    program(Prog, _, _, ROL), 
    nth1(Rank, ROL, Res), !.

% leastPreferred(ProgramID, ResidentIDsList, LeastPreferredResidentID, RankOfThisResident)
% Fonction: Trouve le resident avec le pire rang dans une liste.
% Parametres: Prog: ID du programme, ResidentIDsList: Liste des residents, LeastRes: ID du pire resident, MaxRank: Rang du pire resident
leastPreferred(Prog, [R], R, Rank) :- rankInProgram(R, Prog, Rank), !.
leastPreferred(Prog, [H|T], LeastRes, MaxRank) :-
    leastPreferred(Prog, T, TailRes, TailRank), rankInProgram(H, Prog, HRank),
    ( HRank > TailRank -> (LeastRes = H, MaxRank = HRank) ; (LeastRes = TailRes, MaxRank = TailRank) ).

% matched(ResidentID, ProgramID, MatchSet)
% Fonction: Verifie si un resident a deja un programme.
% Parametres: Res: ID du resident, Prog: ID du programme, MatchSet: Ensemble des matchs
matched(Res, Prog, MatchSet) :- 
    member(match(Prog, Residents), MatchSet), 
    member(Res, Residents), !.

% ===
% LOGIQUE D'OFFRE
% ===

% offer(ResidentID, currentMatchSet, newMatchSet)
% Fonction: Assigne un programme a un resident.
% Parametres: Res: ID du resident, CurSet: Ensemble actuel, NewSet: Nouvel ensemble
offer(Res, CurSet, CurSet) :- matched(Res, _, CurSet), !.
offer(Res, CurSet, NewSet) :- resident(Res, _, ROL), try_match(Res, ROL, CurSet, NewSet).

% try_match(ResidentID, ROL, currentMatchSet, newMatchSet)
% Fonction: Parcourt la liste de preferences du resident.
% Parametres: Res: ID du resident, ROL: Liste de preferences, CurSet: Ensemble actuel, NewSet: Nouvel ensemble
try_match(_, [], Set, Set) :- !.
try_match(Res, [Prog|Rest], CurSet, NewSet) :-
    ( rankInProgram(Res, Prog, MyRank) ->
        program(Prog, _, Cap, _), member(match(Prog, CurRes), CurSet), length(CurRes, L),
        ( L < Cap -> 
            NewRes = [Res|CurRes], update_match(Prog, NewRes, CurSet, NewSet), !
        ; leastPreferred(Prog, CurRes, EvictID, EvictRank),
          ( MyRank < EvictRank -> 
              remove_res(EvictID, CurRes, TempRes), NewRes = [Res|TempRes], 
              update_match(Prog, NewRes, CurSet, NewSet), !
          ; try_match(Res, Rest, CurSet, NewSet) ) )
    ; try_match(Res, Rest, CurSet, NewSet) ).

% ===
% BOUCLE PRINCIPALE
% ===

% pass_all_residents(ResidentList, currentMatchSet, finalMatchSet)
% Fonction: Fait une passe d'offres pour tous les residents.
% Parametres: ResidentList: Liste des residents, CurSet: Ensemble actuel, FinalSet: Ensemble final
pass_all([], Set, Set).
pass_all([R|T], CurSet, FinalSet) :- offer(R, CurSet, NextSet), pass_all(T, NextSet, FinalSet).

% converge_matches(currentMatchSet, finalMatchSet)
% Fonction: Boucle jusqu'a ce que l'ensemble soit stable.
% Parametres: CurSet: Ensemble actuel, FinalSet: Ensemble final
converge(CurSet, FinalSet) :-
    findall(ID, resident(ID, _, _), AllRes), pass_all(AllRes, CurSet, NextSet),
    ( CurSet = NextSet -> FinalSet = CurSet ; converge(NextSet, FinalSet) ).

% gale_shapley
% Fonction: Point d'entree principal du programme.
gale_shapley :-
    findall(match(P, []), program(P, _, _, _), InitSet), converge(InitSet, FinalSet),
    print_matches(FinalSet), print_unmatched(FinalSet), print_stats(FinalSet).

% ===
% AFFICHAGE DES RESULTATS
% ===

% print_matches(MatchSet)
% Fonction: Affiche les jumelages reussis.
% Parametres: Set: Ensemble final
print_matches([]).
print_matches([match(P, ResList)|T]) :- print_list(P, ResList), print_matches(T).

% print_list(ProgramID, ResidentList)
% Fonction: Formate l'affichage d'une liste de residents.
% Parametres: P: ID du programme, ResList: Liste des residents
print_list(_, []).
print_list(P, [R|T]) :- writeMatchInfo(R, P), print_list(P, T).

% writeMatchInfo(ResidentID, ProgramID)
% Fonction: Predicat fourni par le professeur (copie-colle exact).
% Parametres: ResidentID: ID du resident, ProgramID: ID du programme
writeMatchInfo(ResidentID,ProgramID):-
    resident(ResidentID,name(FN,LN),_),
    program(ProgramID,TT,_,_),write(LN),write(','),
    write(FN),write(','),write(ResidentID),write(','),
    write(ProgramID),write(','),writeln(TT).

% print_unmatched(MatchSet)
% Fonction: Affiche les etudiants sans programme.
% Parametres: Set: Ensemble final
print_unmatched(Set) :- findall(R, resident(R, _, _), All), print_un_loop(All, Set).

% print_un_loop(ResidentList, MatchSet)
% Fonction: Boucle pour afficher les etudiants sans programme.
% Parametres: ResidentList: Liste des residents, Set: Ensemble final
print_un_loop([], _).
print_un_loop([R|T], Set) :-
    ( \+ matched(R, _, Set) -> 
        resident(R, name(FN, LN), _),
        write(LN),write(','),write(FN),write(','),write(R),writeln(',XXX,NOT_MATCHED')
    ; true ),
    print_un_loop(T, Set).

% print_stats(MatchSet)
% Fonction: Affiche les statistiques finales.
% Parametres: Set: Ensemble final
print_stats(Set) :-
    findall(R, resident(R,_,_), All), length(All, TotRes),
    count_matched(Set, TotMatched),
    Unmatched is TotRes - TotMatched, 
    findall(C, program(_,_,C,_), Caps), sum_caps(Caps, TotCap), 
    Avail is TotCap - TotMatched,
    write('Number of unmatched residents: '), writeln(Unmatched),
    write('Number of positions available: '), writeln(Avail).

% count_matched(MatchSet, TotalMatched)
% Fonction: Compte le nombre total d'etudiants places.
% Parametres: Set: Ensemble final, Total: Resultat
count_matched([], 0).
count_matched([match(_, ResList)|T], Total) :-
    length(ResList, L),
    count_matched(T, Rest),
    Total is L + Rest.