(
s.waitForBoot {

	// set up OSC listeners
	OSCdef(\cluster, {|msg, time, addr|
		var addrIndex = ~network.indexOfEqual(addr);
		if (addrIndex == nil, {
			var personality = ~personalities.wchoose(~personalityWeights);
			var addition;
			"Registering computer #% with IP '%' as '%' personality"
			  .format(~network.size, addr.ip, personality).postln;
			addr.sendMsg('/personality', ~network.size, personality);
			~network.add(addr);

			// update new personality preferences
			addition = switch (personality)
		      {"pessimist"} {[2, 0, 1, 1, 1]} // increase pessimists
			  {"optimist"} {[0, 2, 1, 1, 1]} // increase optimists
			  {"realist"} {[0, 0, 1, 2, 2]} // increase cons and progs
			  {"conservative"} { ~personalityWeights.normalize; } // prefer popular
			  {"progressive"} { ~personalityWeights.normalize(min: 1, max: 0); }; // prefer unpopular
			~personalityWeights = (~personalityWeights + addition.normalizeSum).normalizeSum;
		}, {
			"Computer #% with IP '%' already registered"
			  .format(addrIndex, ~network[addrIndex].ip).postln;
		});
	}, '/register');

	OSCdef(\cluster2, {|msg, time, addr|
		~personality = msg[2];
		"This computer registered as #% with '%' personality"
	    	.format(msg[1], ~personality).postln;
	}, '/personality'); // def style

	OSCdef(\cluster3, {|msg, time, addr|
		// msg.postln;
		~noteset = [msg[1], msg[2]];
		// ("Now playing: " ++ ~noteset).postln;
	}, '/assign'); // def style

	// piano
	SynthDef(\mdapiano, { |out=0, midi=60, gate=1, vel=80|
		var son = MdaPiano.ar(midi.midicps, gate, vel, 0.8, 0.8, stereo: 1, sustain: 1);
		DetectSilence.ar(son, 0.01, doneAction:2);
		Out.ar(0, son * 0.1);
	}).add;

	SynthDef(\singrain, { |midi = 60, amp = 0.4, sustain = 0.5|
		var sig;
		sig = SinOsc.ar(midi.midicps, 0, amp) * EnvGen.kr(Env.perc(0.01, sustain), doneAction: 2);
		Out.ar(0, sig ! 2);
	}).add;

	s.sync;

	// all computers (including host) register to host IP address;
	~network = List[];
	h = NetAddr("172.27.34.112", 57120);
	"Registering...".postln;
	h.sendMsg('/register');

	// use to get host IP address
	// "ifconfig | grep 'inet '".unixCmd;

	~personalities = ["pessimist", "optimist", "realist", "conservative", "progressive"];
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
	~noteset = [60];

	/*
	[1, 1, 4, 5, 5, 2, 1]
	[5, 5, 1, 1, 2, 4, 3]
	[3, 3, 2, 1, 2, 4, 3]
	*/


	// c.stop;
	c = Task({
		while {true} {
			var closedChord = ~chords.choose + ~penta.choose % 12;
			// closedChord.postln;
			~octave = Array.rand2(8, 2) * 12;
			~chord = closedChord + ~octave + 66;
			~chord.sort;
			// ("Group chord: " ++ ~chord).postln;

			~network.do{ |addr|
				// addr.postln;
				addr.sendMsg('/assign', ~chord[~chord.size.rand], ~chord[~chord.size.rand]);
			};
			5.wait;
		}
	}).play;

	t = Task({
		while {true} {
			~synth = Synth(\singrain, [\midi, ~chord.choose]);
			(0.2.rand + 0.13).wait;
		}
	}).play;

};
);