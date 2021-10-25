module spll 
#(
		parameter	                  PHASE_BITS = 32,
		parameter	[0:0]	          OPT_TRACK_FREQUENCY = 1'b0,
		parameter	[PHASE_BITS-1:0]  INITIAL_PHASE_STEP  = 0,
		parameter	[0:0]	          OPT_GLITCHLESS      = 1'b1,
		localparam	                  MSB=PHASE_BITS-1
	)
(
		input	wire			       i_clk,
		//
		input	wire			       i_ld,
		input	wire [(MSB-1):0]       i_step,
		//
		input	wire			       i_ce,
		input	wire			       i_input,
		input	wire [4:0]		       i_lgcoeff,
		output	wire [PHASE_BITS-1:0]  o_phase,
		output	reg	 [1:0]		       o_err,
		output	wire	 		       o_freq
	);
	
	
	// Signal declarations
	// {{{
	reg		agreed_output=0, lead=0;	// lag
	wire		phase_err;
	reg	[MSB:0]	ctr=0, phase_correction=0, freq_correction=0, r_step=0;
	// }}}

	// agreed_output
	// {{{
	// Any time the input and our counter agree, let's keep track of that
	// bit.  We'll need it in a moment in order to know which signal
	// changed first.
	
	always @(posedge i_clk)
	if (i_ce)
	begin
		if ((i_input)&&(ctr[MSB]))
			agreed_output <= 1'b1;
		else if ((!i_input)&&(!ctr[MSB]))
			agreed_output <= 1'b0;
	end
	// }}}

	// lead
	// {{{
	// Lead is true if the counter changes before the input
	// changes, false otherwise
	//
	always @(*)
	if (agreed_output)
		// We were last high.  Lead is true now
		// if the counter goes low before the input
		lead = (!ctr[MSB])&&(i_input);
	else
		// The last time we agreed, both the counter
		// and the input were low.   This will be
		// true if the counter goes high before the input
		lead = (ctr[MSB])&&(!i_input);
	// }}}

	// phase_err
	// {{{
	// Any disagreement between the high order counter bit and the input
	// is a phase error that we will need to correct
	assign	phase_err = (ctr[MSB] != i_input);
	// }}}

	// phase_correction
	// {{{
	// How much we correct our phase by is a function of our loop
	// coefficient, here represented by 2^{-i_lgcoeff}.
	initial	phase_correction = 0;
	always @(posedge i_clk)
		phase_correction <= {1'b1,{(MSB){1'b0}}} >> i_lgcoeff;
	// }}}

	// ctr
	// {{{
	// Finally, apply a correction
	initial	ctr = 0;
	always @(posedge i_clk)
	if (i_ce)
	begin
		// If we match, then just step the counter forward
		// by one delta phase amount
		if (!phase_err)
			ctr <= ctr + r_step;

		// Otherwise we don't match.  We need to adjust our
		// counter based upon how far off we are.
		// If the counter is ahead of the input, then we should
		// slow it down a touch.
		else if (lead)
		begin
			// This check is necessary to keep us glitch-free
			// If the step is less than the phase correction, the
			// recovered clock might appear to go backwards.
			if (!OPT_GLITCHLESS || r_step > phase_correction)
				ctr <= ctr + r_step - phase_correction;
		end

		// Likewise, if the counter is falling behind the input,
		// then we need to speed it up.
		else // if (lag)
			ctr <= ctr + r_step + phase_correction;
	end
	// }}}

	// o_phase (== ctr)
	// {{{
	// Incidentally, we'll also output this internal phase in case you wish
	// to use it for synchronizing anything with this clock.
	assign	o_phase = ctr;
	assign  o_freq  = ctr[31];
	
	// }}}

	// freq_correction
	// {{{
	// The frequency correction needs to be the phase_correction squared
	// divided by four in order to get a critically damped loop
	initial	freq_correction = 0;
	always @(posedge i_clk)
		freq_correction <= { 3'b001, {(MSB-2){1'b0}} } >> (2*i_lgcoeff);
	// }}}

	// r_step -- frequency tracking
	// {{{
	// On the clock, we'll apply this frequency correction, either slowing
	// down or speeding up the frequency, any time there is a phase error.
	// The exceptions are if 1) we aren't tracking frequency, or 2) the
	// user wants to load in what frequency to use.
	initial	r_step = INITIAL_PHASE_STEP;
	always @(posedge i_clk)
	if (i_ld)
		r_step <= { 1'b0, i_step };
	else if ((i_ce)&&(OPT_TRACK_FREQUENCY)&&(phase_err))
	begin
		if (lead)
			r_step <= r_step - freq_correction;
		else
			r_step <= r_step + freq_correction;
	end
	// }}}

	// o_err
	// {{{
	// Output an error signal as follows:
	// 1. If the two signals match, both one or both zeros, then there is
	//	no phase error.
	// 2. If there is a mismatch and ...
	//	A. Our counter leads our input, then our error is -1, else if
	//	B. Our input leads our counter (!lead), then our error signal
	//		is a +1.
	// All three of these numbers, -1, 0, and 1, all fit within two bits,
	// so that's what we'll use here..
	initial	o_err = 2'h0;
	always @(posedge i_clk)
	if (i_ce)
		o_err <= (!phase_err) ? 2'b00 : ((lead) ? 2'b11 : 2'b01);
		
endmodule
