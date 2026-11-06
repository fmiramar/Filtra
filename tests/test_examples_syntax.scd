// Verify examples compile and parse cleanly
var f1 = thisProcess.interpreter.compileFile("examples/MS20_Complete_Audition.scd");
var f2 = thisProcess.interpreter.compileFile("examples/MS20_Audition_GUI.scd");
var f3 = thisProcess.interpreter.compileFile("examples/MS20Circuit_demo.scd");

if (f1.notNil and: { f2.notNil } and: { f3.notNil }) {
    ("PASS: All example scripts compile with zero syntax errors!").postln;
    0.exit;
} {
    ("FAIL: Syntax error compiling example files!").postln;
    1.exit;
};
