#!/bin/bash

lttng destroy -a
lttng create --output $(pwd)/trace-test-basic 
lttng enable-event -k --syscall -a
lttng add-context -k -t callstack-user-unw
lttng start

./kunwind/libkunwind/tests/test-basic


lttng stop
lttng destroy -a

