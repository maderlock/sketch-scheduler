# sketch-scheduler
Prolog programme to find the most optimal schedule for rehearsing sketches

To run in SWI prolog, call as follows:

    swipl rehearsde.pl
    > consult('yourdbasefilewithoutextension').
    > currentBest(S).

Define the following data in a .pl file that gives the concrete info for the problem:

	rehearsalsPerSlot/1.
	person/1.
	displayName/2.
	director/1.
	known/1.
	dateStrings/1.
	dates/1.
	sketchStrings/1.
	sketches/1.
	activeDate/1.
	neededList/2.
	availability/2.

In addition you need to define currentRequired/2 and currentAvailable/2 to determine whether to include maybes in scheduling and whether you need everyone including the small parts in a sketch or just those marked as required.

For an example, see exmaple/dbase.pl