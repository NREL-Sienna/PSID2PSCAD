function pscad_compat_name(psid_name)
    return replace(psid_name, "-" => "_")
end 

function setup_breaker_operations(project, perturbation::PowerSimulationsDynamics.BranchTrip)
    breaker_name =string("br_", pscad_compat_name(perturbation.branch_name), "_1") 
    breaker_logic = project.find("PSID_Library:simple_brk_logic", breaker_name )
    breaker_logic.set_parameters(enable = 1, t_break = perturbation.time)
    breaker_name =string("br_", pscad_compat_name(perturbation.branch_name), "_2") 
    breaker_logic = project.find("PSID_Library:simple_brk_logic", breaker_name )
    breaker_logic.set_parameters(enable = 1, t_break = perturbation.time)
end  

function setup_breaker_operations(project, perturbation::PowerSimulationsDynamics.GeneratorTrip)
    perturbation_name = get_name(perturbation.device)
    breaker_name =string("br_", pscad_compat_name(perturbation_name), "_1") 
    breaker_logic = project.find("PSID_Library:simple_brk_logic", breaker_name )
    breaker_logic.set_parameters(enable = 1, t_break = perturbation.time)
end  

function setup_output_channnels(project, quantities_to_record::Vector{Tuple{Symbol, String}}, starting_coord; force = true)
    pscad_canvas = project.user_canvas("Main")
    if force == true 
        #TODO: find_output_channels on the main canvas and delete them along with any connected component (if possible)
    end
    for q in quantities_to_record
        channel_name = string(q[1], "_", q[2])
        new_channel = pscad_canvas.add_component(
            "master",
            "pgb",
            starting_coord[1],
            starting_coord[2]
            )
        new_signal = pscad_canvas.add_component(
            "master",
            "datalabel",
            starting_coord[1],
            starting_coord[2]
            )
    
        #new_channel.set_parameters(Name = channel_name)
        new_signal.set_parameters(Name = channel_name)
        starting_coord = (starting_coord[1] + 1, starting_coord[2])
    end 
end 

function set_project_parameters!(project; kwargs...)
    project_params = project.parameters()
    for k in kwargs
        project_params[string(k[1])] = k[2]
    end
    PP.update_parameter_by_dictionary(project, project_params)
end

#TODO - run the three bus tests by re-building each system instead of messing with layers. 
#once tests pass, remove all the layer based functions.
function _add_to_enabled_gens_layer(
    g::DynamicInverter{
        AverageConverter,
        OuterControl{VirtualInertia, ReactivePowerDroop},
        VoltageModeControl,
        FixedDCSource,
        KauraPLL,
        LCLFilter,
    },
    project,
)
    psid_name = get_name(g)
    project.find("PSID_Library_Inverters:DARCO_VSM", psid_name).add_to_layer("enabled_gens")
end

function _add_to_enabled_gens_layer(
    g::DynamicInverter{
        AverageConverter,
        OuterControl{ActivePowerDroop, ReactivePowerDroop},
        VoltageModeControl,
        FixedDCSource,
        FixedFrequency,
        LCLFilter,
    },
    project,
)
    psid_name = get_name(g)
    project.find("PSID_Library_Inverters:DROOP_GFM", psid_name).add_to_layer("enabled_gens")
end

function _add_to_enabled_gens_layer(
    g::DynamicInverter{
        AverageConverter,
        OuterControl{ActivePowerPI, ReactivePowerPI},
        CurrentModeControl,
        FixedDCSource,
        ReducedOrderPLL,
        LCLFilter,
    },
    project,
)
    psid_name = get_name(g)
    project.find("PSID_Library_Inverters:GFL", psid_name).add_to_layer("enabled_gens")
end

function _add_to_enabled_gens_layer(
    g::DynamicGenerator{SauerPaiMachine, SingleMass, SEXS, GasTG, IEEEST},
    project,
)
    psid_name = get_name(g)
    project.find("PSID_Library_Inverters:SAUERPAI_SEXS_GASTG_IEEEST", psid_name).add_to_layer("enabled_gens")
end

function _add_to_enabled_gens_layer(
    g::DynamicGenerator{SauerPaiMachine, SingleMass, SEXS, GasTG, PSSFixed},
    project,
)
    psid_name = get_name(g)
    project.find("PSID_Library_Inverters:SAUERPAI_SEXS_GASTG_PSSFIXED", psid_name).add_to_layer("enabled_gens")
end

function _add_to_enabled_gens_layer(
    g::DynamicGenerator{SauerPaiMachine, SingleMass, SEXS, HydroTurbineGov, IEEEST},
    project,
)
    psid_name = get_name(g)
    project.find("PSID_Library_Inverters:SAUERPAI_SEXS_HYGOV_IEEEST", psid_name).add_to_layer("enabled_gens")
end

function _add_to_enabled_gens_layer(
    g::DynamicGenerator{SauerPaiMachine, SingleMass, SEXS, HydroTurbineGov, PSSFixed},
    project,
)
    psid_name = get_name(g)
    project.find("PSID_Library_Inverters:SAUERPAI_SEXS_HYGOV_PSSFIXED", psid_name).add_to_layer("enabled_gens")
end

function _add_to_enabled_gens_layer(
    g::DynamicGenerator{SauerPaiMachine, SingleMass, SEXS, SteamTurbineGov1, IEEEST},
    project,
)
    psid_name = get_name(g)
    project.find("PSID_Library_Inverters:SAUERPAI_SEXS_TGOV1_IEEEST", psid_name).add_to_layer("enabled_gens")
end

function _add_to_enabled_gens_layer(
    g::DynamicGenerator{SauerPaiMachine, SingleMass, SEXS, SteamTurbineGov1, PSSFixed},
    project,
)
    psid_name = get_name(g)
    project.find("PSID_Library_Inverters:SAUERPAI_SEXS_TGOV1_PSSFIXED", psid_name).add_to_layer("enabled_gens")
end

function _add_to_enabled_gens_layer(
    g::DynamicGenerator{SauerPaiMachine, SingleMass, AVRFixed, TGFixed, PSSFixed},
    project,
)
    psid_name = get_name(g)
    project.find("PSID_Library_Inverters:FIXED_SAUER_PAI", psid_name).add_to_layer(
        "enabled_gens",
    )
    #project.find("PSID_Library_Inverters:SIMPLE_MACHINE", psid_name).add_to_layer("enabled_gens")           #SWITCH HERE TO DECIDE WHICH MACHINE MODEL 
end

function _add_to_enabled_gens_layer(g::Source, project)
    psid_name = get_name(g)
    project.find("PSID_Library_Inverters:INFINITE_BUS", psid_name).add_to_layer(
        "enabled_gens",
    )
end

function enable_dynamic_injection_by_type(sys, project)
    for g in get_components(DynamicInjection, sys)
        psid_name = get_name(g)
        for f in project.find_all(psid_name)
            f.add_to_layer("disabled_gens")
        end
        _add_to_enabled_gens_layer(g, project)
    end
    for g in get_components(Source, sys)
        psid_name = get_name(g)
        for f in project.find_all(psid_name)
            f.add_to_layer("disabled_gens")
        end
        _add_to_enabled_gens_layer(g, project)
    end
end