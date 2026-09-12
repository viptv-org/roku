' Real interpreter contract for the official ifSGNodeDict identity method.
sub Main()
    root = CreateObject("roSGNode","ContentNode")
    first = root.createChild("ContentNode")
    same = root.getChild(0)
    other = root.createChild("ContentNode")
    sgAssert(first.isSameNode(same),"getChild wrapper resolves to the same underlying node")
    sgAssert(not first.isSameNode(other),"different SceneGraph nodes remain distinguishable")
    sgAssert(same.isSameNode(first),"identity check is symmetric for node wrappers")
    print "ROKU_SGNODE_IDENTITY_OK"
end sub

sub sgAssert(condition as boolean, label as string)
    if not condition
        print "TEST_FAIL "; label
        stop
    end if
end sub
