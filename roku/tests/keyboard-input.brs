sub Main()
    keyboard = {text:"cat",textEditBox:{cursorPosition:1,maxTextLength:8}}
    check(KeyboardMobileInput(keyboard,"Lit_o") and keyboard.text = "coat","mobile insertion respects caret")
    check(KeyboardMobileInput(keyboard,"backspace") and keyboard.text = "cat","mobile backspace deletes at caret")
    keyboard.textEditBox.cursorPosition = 0
    check(KeyboardMobileInput(keyboard,"backspace") and keyboard.text = "cat","backspace at start retains text")
    keyboard.textEditBox.cursorPosition = 3
    check(KeyboardMobileInput(keyboard,"Lit_123456") and keyboard.text = "cat","mobile input respects maximum length")
    check(not KeyboardMobileInput(keyboard,"left"),"remote navigation passes through")
    print "KEYBOARD_INPUT_OK"
end sub
sub check(value as boolean,message as string)
    if not value
        print "FAILED: " + message
        stop
    end if
end sub
