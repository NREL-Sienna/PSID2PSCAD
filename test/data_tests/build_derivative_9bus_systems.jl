
using PowerSimulationsDynamicsSurrogates    #need to add package to rebuild systems
const PSIDS = PowerSimulationsDynamicsSurrogates


sys_144 = System(joinpath(@__DIR__, "..", "systems_tests", "144Bus.json"))
sys_9, _ = PSIDS.create_train_system_from_buses(sys_144, collect(1:9))
sources = collect(get_components(Source, sys_9))
for s in sources
    b = get_bus(s)
    set_bustype!(b, BusTypes.PQ)
    remove_component!(sys_9, s)
end 

sim = Simulation!(
    MassMatrixModel,
    sys_9,
    pwd(),
    (0.0, 1.0),
)

to_json(sys_9, joinpath(@__DIR__, "..", "systems_tests", "nine_bus_inv_gen.json"), force = true)
##
#Below here are untested since the old code was moved
sys_9 = System(joinpath(@__DIR__, "psid_files", "nine_bus_inv_gen.json"))

 lv_buses = get_components(x->get_base_voltage(x) < 100.0, Bus, sys_9)
for b in lv_buses
    set_base_voltage!(b, 230.0)
end  
for t in get_components(Transformer2W, sys_9)
     @error t 
    new_line = Line(
        name = get_name(t),
        available = get_available(t),
        active_power_flow = get_active_power_flow(t),
        reactive_power_flow = get_reactive_power_flow(t),
        arc = get_arc(t),
        r = get_r(t),
        x = get_x(t),
        b =(from =0.0, to =0.0),
        rate = get_rate(t),
        angle_limits = (min = -pi/2, max = pi/2),
    ) 
    remove_component!(sys_9, t)
    add_component!(sys_9, new_line)
end 


sim = Simulation!(
    MassMatrixModel,
    sys_9,
    pwd(),
    (0.0, 1.0),
)

to_json(sys_9, joinpath(@__DIR__, "psid_files", "9bus_no_transformers.json"), force = true)
##
sys_9 = System(joinpath(@__DIR__, "psid_files", "9bus_no_transformers.json"))

gen2 = collect(get_components(x->get_name(get_bus(x)) == "Bus_2", ThermalStandard, sys_9))[1]
gfm2  =collect(get_components(x->get_name(get_bus(x)) == "Bus_2", GenericBattery, sys_9))[1]
gfl2  =collect(get_components(x->get_name(get_bus(x)) == "Bus_2", GenericBattery, sys_9))[2]

get_active_power(gen2)
get_active_power(gfm2)
set_base_power!(gfl2, get_base_power(gfl2) * 100)
set_active_power!(gfl2, get_active_power(gfl2) / 100)
set_base_power!(gfm2, get_base_power(gfm2) * 100)
set_active_power!(gfm2, get_active_power(gfm2) / 100)
dg = get_dynamic_injector(gen2)
remove_component!(sys_9, dg )
remove_component!(sys_9, gen2)
show_components(sys_9, Bus)

sim = Simulation!(
    MassMatrixModel,
    sys_9,
    pwd(),
    (0.0, 1.0),
)
##
sim = Simulation(
        MassMatrixModel,
        sys,
        pwd(),
        tspan,
       # genTrip,
        all_branches_dynamic = true,
    )

to_json(sys_9, joinpath(@__DIR__, "psid_files", "9bus_no_transformers_remove1gen.json"), force = true)
