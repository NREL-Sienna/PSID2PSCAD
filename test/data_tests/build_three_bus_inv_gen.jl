        using PowerSystems
        using PowerSimulationsDynamics

        line_to_trip = "Bus_1-Bus_2-i_1" 

        sys = System(joinpath(@__DIR__, "ThreeBusPSCAD.raw"), runchecks = false)
        for l in get_components(PSY.StandardLoad, sys)
            transform_load_to_constant_impedance(l)
        end 

        for g in get_components(Generator, sys)
            if get_number(get_bus(g)) == 101
                add_inv_case78!(sys, g)
            elseif get_number(get_bus(g)) == 102
                add_sauerpai_sexs_tgov1_fixed!(sys, g)   #same generator in 144 bus
            end
        end
        transform_all_lines_dynamic_except_one!(sys, line_to_trip)

        to_json(sys, joinpath(@__DIR__, "..", "systems_tests", "three_bus_inv_gen.json"))
