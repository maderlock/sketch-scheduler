%% Algorithm for creating rehearsal schedule

:- use_module(library(assoc)).
:- dynamic(pairingCache/3).
:- dynamic(orderedPairingCache/3).
:- dynamic(orderedPairingCachecreated/0).

currentBest(S) :-
	known(Known),
	sketches(Sketches),!,
	pairSchedule(S,Sketches,Known),
	displaySchedule(S),nl,
	write(S),nl.

possibleSketches :-
	findall(D,activeDate(D),ActiveDays),
	outputPossibleSketches(ActiveDays).
outputPossibleSketches([]) :- !.
outputPossibleSketches([A|As]) :-
	displayDate(A),nl,
	findall(S,doable(S,A),Ss),
	displaySketchesAndActors(Ss),nl,
	outputPossibleSketches(As).

% Sketches that can be performed with the people available on a date
doable(Sketch, Date) :-
	sketch(Sketch),
	activeDate(Date),
	findall(P,currentRequired(P,Sketch),Ps),
	allAvailable(Ps, Date).

% Helper functor that passes if all entries in list are available on date of second
allAvailable([], _) :- !.
allAvailable([Pers|Ps], Date) :-
	currentAvailable(Pers, Date),
	allAvailable(Ps, Date).

%% PAIRS OF SKETCHES %%

% Pairs of sketches that share the most people
orderedPairing([S1,S2]) :-
	createOrderedPairingCache,
	orderedPairingCache(S1,S2,_).

% Order pairs of sketches and order by overlap
createOrderedPairingCache :-
	orderedPairingCachecreated,!.
createOrderedPairingCache :-
	createPairingCache,
	pairsOfSketches(PSs),
	predsort(comparePairs,PSs,Sorted),
	storeOrderedPairs(Sorted),
	assertz(orderedPairingCachecreated).

% Reverse ordering of pairing orders
comparePairs(Order,[S1a,S1b],[S2a,S2b]) :-
	pairing(S1a,S1b,Ord1),
	pairing(S2a,S2b,Ord2),
	((Ord1 == Ord2, Order = <);
	 compare(Order,Ord2,Ord1)).

storeOrderedPairs([]) :- !.
storeOrderedPairs([[S1,S2]|Ss]) :-
	pairing(S1,S2,Ordering),
	assertz(orderedPairingCache(S1,S2,Ordering)),
	storeOrderedPairs(Ss).

%% Get pairs of sketches with highest ordered first
pairsOfSketches(PSs) :-
	sketches(Ss),
	pairsOfSketches(Ss,[],PSs),!.

pairsOfSketches([],PSs,PSs) :- !.
pairsOfSketches([S|Ss],PSsIn,PSs) :-
	pairsOfSketches(S,Ss,PSsIn,PSsMid),
	pairsOfSketches(Ss,PSsMid,PSs).

pairsOfSketches(_,[],PSs,PSs) :- !.
pairsOfSketches(S1,[S2|Ss],PSsIn,PSs) :-
	pairsOfSketches(S1,Ss,[[S1,S2]|PSsIn],PSs).

%% Create cache of pairs of sketches
createPairingCache :-
	pairsOfSketches(PSs),
	createPairingCache(PSs),!.

%% Each pair gets pairing/3 called
createPairingCache([]) :- !.
createPairingCache([[S1,S2]|Ss]) :-
	pairing(S1, S2, _),!, % Note that pairing/3 lazily creates itself
	createPairingCache(Ss).

% Score pairs of sketches by their overlap
pairing(S1, S2, OverlapNum) :-
	pairingCache(S1, S2, OverlapNum).
pairing(S1, S2, OverlapNum) :-
	findall(P1,currentRequired(P1,S1),Ps1),
	findall(P2,currentRequired(P2,S2),Ps2),
	intersection(Ps1,Ps2,JointPs),
	length(JointPs, OverlapNum),
	assertz(pairingCache(S1, S2, OverlapNum)).

%% SCHEDULING ALGORITHM %%

% Default
schedule(Schedule,Sketches) :-
	schedule(Schedule, Sketches, []).
schedule(Schedule, Sketches, Known) :-
	pairSchedule(Schedule, Sketches, Known),
	overallHeuristics(Schedule).

%% HARD CONSTRAINTS %%

overallHeuristics(Schedule).

%% SIMPLE

% Map all sketches to a date, with each date having at most 2 sketches
%TODO: Allow sketches to be here more than once
simpleSchedule(Schedule, Sketches) :-
	simpleSchedule(Schedule, Sketches, []).
simpleSchedule(Schedule, Sketches, Known) :-
	list_to_assoc(Known,ExStart),!,
	simpleScheduleDo(ExStart, ExFinal, Sketches),
	assoc_to_list(ExFinal, Schedule).

simpleScheduleDo(Existing, Existing, []).
simpleScheduleDo(Existing, FinalExisting, [Sketch|Ss]) :-
	doable(Sketch, Date),
	rehearsalsPerSlot(Max),
	tryToAddToExisting(Existing, Existing2, [Sketch], Date, Max),
	simpleScheduleDo(Existing2, FinalExisting, Ss).

%% PAIRS

pairSchedule(Schedule, Sketches) :-
	pairSchedule(Schedule, Sketches, []).
pairSchedule(Schedule, Sketches, Known) :-
	list_to_assoc(Known,ExStart),!,
	pairScheduleDo(ExStart, ExFinal, Sketches),
	assoc_to_list(ExFinal, Schedule).

% Find a pair of sketches with either both needing to be scheduled,
%   or one in existing and the other to be scheduled
% If only one left, just schedule by iteself
pairScheduleDo(Existing, Existing, []).
% Single sketch passed to simple
pairScheduleDo(Existing, FinalExisting, [Sketch]) :-
	simpleScheduleDo(Existing, FinalExisting, [Sketch]).
% At least two sketches left - assign both new to a slot
pairScheduleDo(Existing, FinalExisting, Ss) :-
	orderedPairing([Sketch1,Sketch2]),
	memberchk(Sketch1,Ss), % Make sure they still need to be done
	memberchk(Sketch2,Ss), % Make sure they still need to be done
	doable(Sketch1, Date), % doable on the same date
	doable(Sketch2, Date), % doable on the same date
	rehearsalsPerSlot(Max),
	tryToAddToExisting(Existing, Existing2, [Sketch1,Sketch2], Date, Max),
	select(Sketch1, Ss, Ss2), % Remove S1 and S2 from NewSs
	select(Sketch2, Ss2, NewSs), % Remove S1 and S2 from NewSs
	pairScheduleDo(Existing2, FinalExisting, NewSs).

%% ASSOCIATIVE LIST FUNCTORS %%

tryToAddToExisting(Existing, Existing2, Sketches, Date, Max) :-
	(get_assoc(Date, Existing, DateList) ; DateList = []),!,
	length(Sketches, NewLen),
	length(DateList, Len), !,
	Total is (Len + NewLen), Total =< Max, % total new length must be less than maximum
	append(Sketches, DateList, DateList2),
	put_assoc(Date, Existing, DateList2, Existing2).

%% DISPLAY %%

sketch(S) :-
	sketches(List), member(S, List).
date(D) :-
	dates(List), member(D, List).

displaySchedule([]) :- !.
displaySchedule([Day-Sketches|Remainder]) :-
	displayDate(Day),nl,
	displaySketchesAndActors(Sketches),nl,
	displaySchedule(Remainder).

displayScheduleForActors(Schedule) :-
	findall(P,person(P),Ps),!,
	displayScheduleForActors(Ps,Schedule).
displayScheduleForActors([],_) :- !.
displayScheduleForActors([A|As],Schedule) :-
	displayActor(A),nl,
	displaySchedulePerActor(A,Schedule),
	displayScheduleForActors(As,Schedule).

displaySchedulePerActor(_,[]) :- !.
displaySchedulePerActor(Actor,[Day-[Sketch]|Remainder]) :-
   ((currentRequired(Actor, Sketch),!,
		write('  '),
		displayDate(Day),nl,
		write('    Mid - '),
		displaySketch(Sketch),nl
   );write('')),
	displaySchedulePerActor(Actor,Remainder).
displaySchedulePerActor(Actor,[Day-[Sketch1,Sketch2]|Remainder]) :-
    (((currentRequired(Actor, Sketch1);currentRequired(Actor, Sketch2)),!,
		write('  '),
		displayDate(Day),nl,
	    ((currentRequired(Actor, Sketch1),!,
			write('    Early - '),
			displaySketch(Sketch1),nl
	    );write('')),
	    ((currentRequired(Actor, Sketch2),!,
			write('    Late - '),
			displaySketch(Sketch2),nl
	    );write(''))
    );write('')),
	displaySchedulePerActor(Actor,Remainder).

displaySketchesAndActors([]) :- !.
displaySketchesAndActors([S|Ss]) :-
	write('  '),
	displaySketch(S),
	write(' - '),
	displayActorsInSketch(S),
	nl,
	displaySketchesAndActors(Ss).

displaySketch(Sketch) :-
	sketch(Sketch),
	sketches(List),
	nth0(SketchNum, List, Sketch),
	sketchStrings(SketchStrings),
	nth0(SketchNum, SketchStrings, SketchString),
	write(SketchString),!.
displaySketches([S]) :-
	write(' '),
	displaySketch(S),!.
displaySketches([S|Ss]) :-
	write(' '),
	displaySketch(S),
	write(','),nl,
	displaySketches(Ss).

displayDate(Date) :-
	date(Date),
	dates(List),
	nth0(DayNum, List, Date),
	dateStrings(DateStrings),
	nth0(DayNum, DateStrings, DateString),
	write(DateString),!.

displayActorsInSketch(Sketch) :-
	sketch(Sketch),
	findall(P,currentRequired(P,Sketch),Ps),
	displayActors(Ps),!.

displayActors([A]) :-
	displayActor(A),!.
displayActors([A|As]) :-
	displayActor(A),
	write(', '),
	displayActors(As).

displayActor(A) :-
	displayName(A,Name),
	write(Name),!.

%% Required / maybe options

certain(Person, Day) :-
	dates(List), nth0(DayNum, List, Day), certainNum(Person, DayNum).
certainNum(robe, _).
certainNum(camille, _).
certainNum(Person, DayNum) :-
	availability(Person, List), nth0(DayNum, List, yes).
maybe(Person, Day) :-
	dates(List), nth0(DayNum, List, Day), maybeNum(Person, DayNum).
maybeNum(Person, DayNum) :-
	availability(Person, List), nth0(DayNum, List, maybe).

available(Person, Day) :-
	dates(List), nth0(DayNum, List, Day), availableNum(Person, DayNum).
availableNum(Person, DayNum) :-
	certainNum(Person, DayNum).
availableNum(Person, DayNum) :-
	maybeNum(Person, DayNum).

required(Person, Sketch) :-
	sketches(List), nth0(SketchNum, List, Sketch), requiredNum(Person, SketchNum).
requiredNum(Person, SketchNum) :-
	neededList(Person, List), nth0(SketchNum, List, required).
small(Person, Sketch) :-
	sketches(List), nth0(SketchNum, List, Sketch), smallNum(Person, SketchNum).
smallNum(Person, SketchNum) :-
	neededList(Person, List), nth0(SketchNum, List, small).

inSketch(Person, Sketch) :-
	sketches(List), nth0(SketchNum, List, Sketch), inSketchNum(Person, SketchNum).
inSketchNum(Person, SketchNum) :-
	requiredNum(Person, SketchNum).
inSketchNum(Person, SketchNum) :-
	smallNum(Person, SketchNum).
