# TODO - measure P and Q of each device is PSCAD, don't use internal calculations.
# TODO - come up with constant TOLERANCES for how close the values should be when checking (make this systematic and as tight as possible) 
# TODO - cleanup the tempdir 

################ OPTIONS #################
#GENERAL PARAMETERS WHICH APPLY TO BOTH PSID AND PSCAD 
base_name = "nine_bus_inv_gen"
line_to_trip = "Bus_8-Bus_9-i_1" 
t_sample =  5.0e-4 #* 1e6 
t_dynamic_sim = 5.0

#PSCAD SPECIFIC PARAMETERS
build_from_scratch = false 
time_step_pscad = 25e-6 * 1e6  
t_initialization_pscad = 4.0
t_inv_release_pscad = 3.0
t_gen_release_pscad = 3.0
add_pvbus_sources = true  
t_pvbussource_release_pscad = 3.0
fortran_version = ".gf46"        #laptop
#fortran_version = ".if18_x86"   #remote desktop
#TODO - add check for fortran version 

#PSID SPECIFIC PARAMETERS 
solver_psid = Rodas5()
abstol_psid = 1e-14

plotting = true   
##########################################

# @testset "test_psid_paper" begin
    base_path = (joinpath(pwd(), string("test_", base_name)))
    !isdir(base_path) && mkdir(base_path)
   # try 
        # 1. Build the system in PSID. 
        sys = System(joinpath(@__DIR__, "systems_tests", string(base_name, ".json")), runchecks = false)
        #b = get_component(Bus, sys, "Bus_1")   #added these two lines in a prior version, not sure why 
        #set_angle!(b, -0.1)                    #added these two lines in a prior version, not sure why 
        # 2. Simulate the PSID system.
        perturbation = BranchTrip(0.1, Line, line_to_trip)
        sim = Simulation!(
            MassMatrixModel,
            sys,
            pwd(),
            (0.0, t_dynamic_sim),
            perturbation;
            file_level = Logging.Error,
            frequency_reference = ReferenceBus(),
        )
        inner_vars_map = export_inner_vars(sim)
        @assert small_signal_analysis(sim).stable
        execute!(sim, solver_psid; saveat=0:t_sample:t_dynamic_sim, abstol = abstol_psid)
        psid_results = read_results(sim)

        # 3. Build the system in PSCAD (based on the PSID system)
        PP = pyimport("PSCAD_Python")
        pscad = PP.basic_pscad_startup()
        sleep(3)    #need to let the default files load in pscad before loading the workspace you want 
        hodge_certificate = pscad.get_available_certificates()[1246234737]
        pscad.get_certificate(hodge_certificate)

        pscad.new_workspace(PyObject(joinpath(base_path,string(base_name, ".pswx"))))  
        pscad.load(PyObject(joinpath(pwd(), "PSID2PSCAD", "_pscad_libraries", "PSID_Library.pslx")))
        pscad.load(PyObject(joinpath(pwd(), "PSID2PSCAD", "_pscad_libraries", "PSID_Library_Inverters.pslx")))

        if build_from_scratch 
            project = pscad.create_case(PyObject(joinpath(base_path, base_name)))
            canvas = project.canvas("Main")
            set_project_parameters!(canvas; size = "100X100")
            set_project_parameters!(project; PlotType = "OUT")
            build_system(
                sys,
                project,
                bus_coords_9;
                add_gen_breakers = true,
                add_load_breakers = true,
                add_line_breakers = true,
                add_multimeters = true,
                add_pvbus_sources = add_pvbus_sources, 
            )
            parameterize_system(sys, project) 
            quantities_to_record = Tuple{Symbol, String}[]
        
            buses = collect(get_components(Bus, sys))
            for b in buses
                push!(quantities_to_record,(:v, get_name(b)))
                push!(quantities_to_record,(:ph, get_name(b))) 
            end
            for g in collect(get_components(DynamicInjection, sys))
                push!(quantities_to_record, (:f, pscad_compat_name(get_name(g))))
                push!(quantities_to_record, (:P, pscad_compat_name(get_name(g))))
                push!(quantities_to_record, (:Q, pscad_compat_name(get_name(g))))
            end  
            for g in collect(get_components(DynamicInverter, sys))
                push!(quantities_to_record, (:V_cnv_d, pscad_compat_name(get_name(g))))
                push!(quantities_to_record, (:V_cnv_q, pscad_compat_name(get_name(g))))
                push!(quantities_to_record, (:I_cnv_d, pscad_compat_name(get_name(g))))
                push!(quantities_to_record, (:I_cnv_q, pscad_compat_name(get_name(g))))
                push!(quantities_to_record, (:V_flt_d, pscad_compat_name(get_name(g))))
                push!(quantities_to_record, (:V_flt_q, pscad_compat_name(get_name(g))))
                push!(quantities_to_record, (:I_flt_d, pscad_compat_name(get_name(g))))
                push!(quantities_to_record, (:I_flt_q, pscad_compat_name(get_name(g))))
            end 
            for g in collect(get_components(DynamicGenerator, sys))
                push!(quantities_to_record, (:Vd, pscad_compat_name(get_name(g))))
                push!(quantities_to_record, (:Vq, pscad_compat_name(get_name(g))))
                push!(quantities_to_record, (:Id, pscad_compat_name(get_name(g))))
                push!(quantities_to_record, (:Iq, pscad_compat_name(get_name(g))))
            end 
            if add_pvbus_sources
                for b in collect(get_components(x -> (PowerSystems.get_bustype(x) == BusTypes.REF || PowerSystems.get_bustype(x) == BusTypes.PV), Bus, sys))
                    push!(quantities_to_record, (:isource, pscad_compat_name(get_name(b)))) 
                end 
            end
            setup_output_channnels(project, quantities_to_record, (15, 2)) 
            project.save()   
            pscad.save_workspace()
        end 
        # 4. Run the PSCAD system to steady state.
        pscad.load(PyObject(joinpath(base_path, string(base_name, ".pswx"))))  
        project = pscad.project(base_name)
            
        PP.update_parameter_by_name(project.find("master:const", "t_INV"), "Value", t_inv_release_pscad)
        PP.update_parameter_by_name(project.find("master:const", "t_GEN"), "Value", t_gen_release_pscad)
        PP.update_parameter_by_name(project.find("master:const", "t_RAMP"), "Value", 0.1)
        for x in project.find_all("PSID_Library:PVBusSource")
            PP.update_parameter_by_name(x, "t_breaker", t_pvbussource_release_pscad)
        end 

        set_project_parameters!(
            project;
            snapshot_filename = "snap_initialization",
            SnapType = 1,  # 0: no snapshot, 1: single snapshot, 2: multiple snapshots (same file), 3:  multiple snapshots (separate files)  
            SnapTime = t_initialization_pscad,
            StartType =  0,  # 0:  don't load snapshot, 1: load snapshot 
            time_duration = t_initialization_pscad,
            sample_step = t_sample * 10^6,  #pscad requires time in micro seconds
            time_step = time_step_pscad,
        ) 

        pscad_output_folder_path = joinpath(base_path, string(base_name, fortran_version))
        if isdir(pscad_output_folder_path)
            foreach(rm, filter(!endswith(".snp") , readdir(pscad_output_folder_path,join=true))) #Don't delete snapshot file.
        end 
        sim_time = @timed project.run()


        df = collect_pscad_outputs(pscad_output_folder_path)[1]  
        open(joinpath(base_path, "pscad_results_init.csv"), "w") do io
            CSV.write(io, df)
        end

        # 5. Check the result against PSID (options for plotting to debug)     
        pscad_results = CSV.read(joinpath(base_path, "pscad_results_init.csv"), DataFrame)
        if plotting 
            p = plot_psid_pscad_initialization_comparison(sys, psid_results, pscad_results, inner_vars_map)
            display(p)
        end 
        psid_pscad_initialization_comparison(sys, psid_results, pscad_results, inner_vars_map)
        project.save()   
        pscad.save_workspace()

        # 6. Run the dynamics in PSCAD (use snapshot)
        pscad.load(PyObject(joinpath(base_path, string(base_name, ".pswx"))))  
        project = pscad.project(base_name)
        
        setup_breaker_operations(project, perturbation, t_initialization_pscad)
        load_snapshot_path  = joinpath(pscad_output_folder_path, "snap_initialization.snp")
        set_project_parameters!(
            project;
            snapshot_filename = "snap_dynamics", 
            startup_filename = load_snapshot_path,
            SnapType = 1,  # 0: no snapshot, 1: single snapshot, 2: multiple snapshots (same file), 3: multiple snapshots (separate files)  
            SnapTime = t_dynamic_sim,
            StartType =  Int64(1), # 0:  don't load snapshot, 1: load snapshot 
            time_duration = t_dynamic_sim,
            sample_step = t_sample * 10^6,  #pscad requires time in micro seconds
            time_step = time_step_pscad,
        ) 
 
        if isdir(pscad_output_folder_path)
            foreach(rm, filter(!endswith(".snp") , readdir(pscad_output_folder_path,join=true))) #Don't delete snapshot file.
        end 

        sim_time = @timed project.run()
        df = collect_pscad_outputs(pscad_output_folder_path)[1]  
        open(joinpath(base_path, "pscad_results_dynamics.csv"), "w") do io
            CSV.write(io, df)
        end

        # 7. Check the result against PSID (options for plotting to debug)     
        pscad_results = CSV.read(joinpath(base_path, "pscad_results_dynamics.csv"), DataFrame)
        if plotting 
            p = plot_psid_pscad_fault_comparison(sys, psid_results, pscad_results)
            display(p)
        end 
        #psid_pscad_fault_comparison(sys, psid_results, pscad_results)  #TODO - check the results numerically 

        pscad.release_all_certificates() 
        pscad.quit()    
        logging.shutdown()

#=     finally
        @info("removing test files")
        rm(base_path, force = true, recursive = true)    #Comment this line if you want to leave the results files
    end 
end 
 =#
