(
s.waitForBoot {
	// 1. choose a machine to be the host
	// 2. find the host's IP address by running the following
	//    "ifconfig | grep 'inet '".unixCmd;
	// 3. set the below variable to that value on all machine
	//    (including the host) in the network
	// 4. run
	~hostAddr = "172.27.34.112";

	// set up OSC listeners
	OSCdef(\cluster, {|msg, time, addr|
		var addrIndex = ~network.indexOfEqual(addr);

		// mark host
		if (~isHost == false, {
			"cluster: Marking this machine as cluster host".postln;
			~isHost = true;
			c.play;
		});

		// see if machine already registered
		if (addrIndex == nil, {
			var personality = ~personalities.wchoose(~personalityWeights);
			var addition;

			// add machine to registery and send register confirmation and personality assignment
			"cluster: Registering machine #% with IP '%' as '%' personality"
			  .format(~network.size, addr.ip, personality).postln;
			addr.sendMsg('/personality', ~network.size, personality);
			~network.add(addr);

			// update new personality preferences
			addition = switch (personality)
		      {\pessimist} {[2, 0, 1, 1, 1]} // increase pessimists
			  {\optimist} {[0, 2, 1, 1, 1]} // increase optimists
			  {\realist} {[0, 0, 1, 2, 2]} // increase cons and progs
			  {\conservative} { ~personalityWeights.normalize; } // prefer popular
			  {\progressive} { ~personalityWeights.normalize(min: 1, max: 0); }; // prefer unpopular
			~personalityWeights = (~personalityWeights + addition.normalizeSum).normalizeSum;
		}, {
			"cluster: Machine #% with IP '%' already registered"
			  .format(addrIndex, ~network[addrIndex].ip).postln;
		});
	}, '/register');

	OSCdef(\cluster2, {|msg, time, addr|
		// assign personality information to computer
		~personality = msg[2];
		switch (msg[2],
			\pessimist, {
				~octaves = [-3, -2];
				~feedbackLow = 0.4;
				~feedbackDiff = 0.6;
				~attackLow = 0.5;
				~attackDiff = 0.8;
				~sustainLow = 0.2;
				~sustainDiff = 0.6;
				~releaseLow = 0.4;
				~releaseDiff = 0.6;
			}, \optimist, {
				~octaves = [1, 2, 3];
				~feedbackLow = 0.8;
				~feedbackDiff = 0.2;
				~attackLow = 0.0;
				~attackDiff = 0.02;
				~sustainLow = 0.0;
				~sustainDiff = 0.0;
				~releaseLow = 0.05;
				~releaseDiff = 0.15;
			}, \realist, {
				~octaves = [-1, 0, 1];
				~feedbackLow = 0.3;
				~feedbackDiff = 0.2;
				~attackLow = 0.0;
				~attackDiff = 0.05;
				~sustainLow = 0.05;
				~sustainDiff = 0.1;
				~releaseLow = 0.2;
				~releaseDiff = 0.3;
			}, \conservative, {
				~octaves = [-1, 0];
				~feedbackLow = 0.5;
				~feedbackDiff = 0.2;
				~attackLow = 0.1;
				~attackDiff = 0.2;
				~sustainLow = 0.3;
				~sustainDiff = 0.2;
				~releaseLow = 0.2;
				~releaseDiff = 0.3;
			}, \progressive, {
				~octaves = [0, 1];
				~feedbackLow = 0.0;
				~feedbackDiff = 0.2;
				~attackLow = 0.1;
				~attackDiff = 0.6;
				~sustainLow = 0.05;
				~sustainDiff = 0.1;
				~releaseLow = 0.0;
				~releaseDiff = 0.1;
		});

		"cluster: This computer registered as #% with '%' personality"
	    	.format(msg[1], ~personality).postln;
		t.start;
	}, '/personality'); // def style


	OSCdef(\cluster3, {|msg, time, addr|
		// receive note assignment
		~noteset = [msg[1], msg[2]] + (12 * [~octaves.choose, ~octaves.choose]);
		"cluster: Noteset assigned: %".format(~noteset).postln;
	}, '/assign'); // def style

	SynthDef(\clusterpatch, { |midi, feedback, attack, sustain, release|
		var signal = SinOscFB.ar(midi.midicps, feedback, 1)
		  * EnvGen.kr(Env.linen(attack, sustain, release, 0.5, \welch), doneAction: 2);
		Out.ar(0, signal ! 2);
	}).add;

	~isHost = false;
	~network = List[];
	c = Task({
		while {true} {
			var chord = (~chords.choose + ~penta.choose % 12) + ~centerNote;
			chord.sort;
			"cluster: Broadcasting chord: %".format(chord).postln;
			~network.do{ |addr|
				addr.sendMsg('/assign', chord[chord.size.rand], chord[chord.size.rand]);
			};
			7.wait;
		}
	});

	t = Task({
		while {true} {
			var feedback = ~feedbackDiff.rand + ~feedbackLow;
			var attack   =   ~attackDiff.rand +   ~attackLow;
			var sustain  =  ~sustainDiff.rand +  ~sustainLow;
			var release  =  ~releaseDiff.rand +  ~releaseLow;
			var duration = attack + sustain + release;
			var waitTime = attack + sustain + (2 * release + 0.1).rand;
			~synth = Synth(\clusterpatch, [\midi, ~noteset.choose, \feedback, feedback,
				\attack, attack, \sustain, sustain, \release, release]);
			waitTime.wait;
		}
	});

	s.sync;

	/*
	// set defaults for all machine parameters
	~personality = "none";
	~feedbackLow = 0.0;
	~feedbackDiff = 0.0;
	~attackLow = 0.1;
	~attackDiff = 0.0;
	~sustainLow = 0.1;
	~sustainDiff = 0.0;
	~releaseLow = 0.4;
	~releaseDiff = 0.2;
	~octaves = [0];
	*/

	TempoClock.tempo = 1;
	~personalities = [\pessimist, \optimist, \realist, \conservative, \progressive];
	~personalityWeights = [1, 1, 1, 1, 1].normalizeSum;
	~penta = Scale.major.degrees[[0,1,2,4,5]];
	~chords = [
		// major third cluster
		[0, 2, 4, 7],
		// fifths cluster
		[0, 2, 7, 9],
		// fourths
		[0, 3, 5, 10],
		// half diminished
		[0, 3, 6, 10],
		// minor 7
		[0, 3, 7, 10],
		// major 6
		[0, 4, 7, 9],
		// major 7
		[0, 4, 7, 11],
	];
	~centerNote = 58;
	~noteset = [~centerNote];

	// all computers (including host) register to host IP address;
	"cluster: Registering machine...".postln;
	h = NetAddr(~hostAddr, 57120);
	h.sendMsg('/register');
};
);