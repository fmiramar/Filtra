/*
    Filtra for SuperCollider
    FormantMorph: Coordinated Multi-Formant Vowel Bank with Continuous Log-Frequency Trajectory Morphing
    Parallel 3-formant 2nd-order TPT bandpass bank with smooth log-frequency morphing across 5 vowels
    ([a], [e], [i], [o], [u]) and formant bandwidth/frequency scaling.
*/

FormantMorph : UGen {
    *ar { arg in, morph = 0.0, vowelA = 0, vowelB = 1, freqScale = 1.0, bwScale = 1.0, mul = 1.0, add = 0.0;
        ^this.multiNew('audio', in, morph, vowelA, vowelB, freqScale, bwScale).madd(mul, add);
    }

    checkInputs {
        if (rate == 'audio') {
            if (inputs.at(0).rate != 'audio') {
                ^(": audio rate input required for in");
            };
        };
        ^this.checkValidInputs;
    }
}
