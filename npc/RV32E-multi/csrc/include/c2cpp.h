#ifdef __cplusplus
extern "C" {
#endif
	void npc_sdb_mainloop();		//c2cpp
	void npc_init(int argc, char *argv[]);	//c2cpp
	void execute(uint64_t n);		//cpp2c
	void quit_simulation();			//cpp2c
	void sim_finish();				//cpp2c
	void halt();					//cpp2c
#ifdef __cplusplus
}
#endif