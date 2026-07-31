name ?= sample
TESTSPACE := testspace

all: test_sim

$(TESTSPACE):
	mkdir -p $(TESTSPACE)

test_sim: $(TESTSPACE)
	iverilog -g2012 -o $(TESTSPACE)/simv sim/testbench.v src/cpu.v
	vvp $(TESTSPACE)/simv

clean:
	rm -rf $(TESTSPACE)
