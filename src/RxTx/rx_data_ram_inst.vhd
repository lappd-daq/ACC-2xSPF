rx_data_ram_inst : rx_data_ram PORT MAP (
		data	 => data_sig,
		rd_aclr	 => rd_aclr_sig,
		rdaddress	 => rdaddress_sig,
		rdclock	 => rdclock_sig,
		rden	 => rden_sig,
		wraddress	 => wraddress_sig,
		wrclock	 => wrclock_sig,
		wren	 => wren_sig,
		q	 => q_sig
	);
