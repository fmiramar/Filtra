/*
    FilterSuite for SuperCollider
    ZMorph: Original Digital Multiresonant Filter Response Morphing
    Reference Concept: Rossum / E-mu Z-plane morphing (original DSP and presets, no proprietary ROM)
    Parallel processing of Shape A and Shape B with equal-gain response crossfade morph in [0, 1]
*/

ZMorph : UGen {
    *ar { |in, morph = 0.0, shapeA = 0, shapeB = 1|
        ^this.multiNew('audio', in, morph, shapeA, shapeB)
    }

    checkInputs {
        if (inputs.at(0).rate != 'audio') {
            ^("ZMorph: first input (in) must be audio rate");
        };
        ^this.checkValidInputs;
    }
}

FSZMorph : ZMorph {}
