 ' Handle mobile input that bubbles past native controls, including while actions have focus.
function KeyboardMobileInput(keyboard as object,key as string) as boolean
    if lcase(left(key,4)) <> "lit_" and lcase(key) <> "backspace" then return false
    edit = keyboard.textEditBox
    value = keyboard.text
    cursor = edit.cursorPosition
    if cursor < 0 or cursor > len(value) then cursor = len(value)
    if lcase(key) = "backspace"
        if cursor > 0
            value = left(value,cursor-1) + mid(value,cursor+1)
            cursor--
        end if
    else
        literal = mid(key,5)
        value = left(value,cursor) + literal + mid(value,cursor+1)
        cursor += len(literal)
    end if
    if len(value) <= edit.maxTextLength
        keyboard.text = value
        edit.cursorPosition = cursor
    end if
    return true
end function
