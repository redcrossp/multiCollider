(
s.waitForBoot {
	// set up OSC listeners
	OSCdef(\cluster, {|msg, time, addr|
		~network.add(addr);
		~network.postln;
	}, '/register');
	OSCdef(\cluster2, {|msg, time, addr|
		msg.postln;
		~noteset = [msg[1], msg[2]];
		("Now playing: " ++ ~noteset).postln;
	}, '/assign'); // def style

	// a simple piano synthdef using MdaPiano
	SynthDef(\mdapiano, { |out=0, midi=60, gate=1, vel=80|
		var son = MdaPiano.ar(midi.midicps, gate, vel, 0.8, 0.8, stereo: 1, sustain: 1);
		DetectSilence.ar(son, 0.01, doneAction:2);
		Out.ar(0, son * 0.1);
	}).add;

	s.sync;


	// all computers (including host) register to host IP address;
	h = NetAddr("172.27.34.112", 57120);
	~network = List[];
	h.sendMsg('/register');

	// use to get host IP address
	// "ifconfig | grep 'inet '".unixCmd;

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

	// c.stop;
	c = Task({
		while {true} {
			var closedChord = ~chords.choose + ~penta.choose % 12;
			// closedChord.postln;
			~octave = Array.rand2(8, 1) * 12;
			~chord = closedChord + ~octave + 60;
			~chord.sort;
			("Group chord: " ++ ~chord).postln;

			~network.do{ |addr|
				addr.postln;
				~network[0].sendMsg('/assign', ~chord[~chord.size.rand], ~chord[~chord.size.rand]);
			};
			5.wait;
		}
	}).play;

	t = Task({
		while {true} {
			~synth = Synth(\mdapiano, [\midi, ~noteset.choose]);
			(0.2.rand + 0.13).wait;
		}
	}).play;

};
);