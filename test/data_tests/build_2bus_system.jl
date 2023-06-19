using PowerSystems
using PowerSimulationsDynamics

sys_2bus = System(100.0)
sys_144bus = System(joinpath(pwd(), "PSID2PSCAD", "test", "systems_tests",  "144Bus.json" ))

#GET ALL COMPONENTS 
batt_gfm_old = get_component(GenericBattery, sys_144bus,"GFM_Battery_53" )
gfm_old = get_component(DynamicInverter, sys_144bus,"GFM_Battery_53" )
batt_gfl_old = get_component(GenericBattery, sys_144bus,"GFL_Battery_53" )
gfl_old = get_component(DynamicInverter, sys_144bus,"GFL_Battery_53" )
thermal_standard_old = get_component(ThermalStandard, sys_144bus,"generator-53-1" )
gen_old = get_component(DynamicGenerator, sys_144bus,"generator-53-1" )
transformer_2w_old =  get_component(Transformer2W, sys_144bus,"Bus_59-Bus_53-i_1" ) 
arc_old = get_arc(transformer_2w_old)
b1_old = get_from(arc_old)
b2_old = get_to(arc_old)
area_old =  get_component(Area, sys_144bus,"1" )
load_zone_old =  get_component(LoadZone, sys_144bus,"1" )

#REMOVE FROM OLD SYSTEM
remove_component!(sys_144bus, gfm_old)
remove_component!(sys_144bus, batt_gfm_old)
remove_component!(sys_144bus, gfl_old)
remove_component!(sys_144bus, batt_gfl_old)
remove_component!(sys_144bus, gen_old)
remove_component!(sys_144bus, thermal_standard_old)
remove_component!(sys_144bus, arc_old)
remove_component!(sys_144bus, transformer_2w_old)
remove_component!(sys_144bus, b1_old)
remove_component!(sys_144bus, b2_old)
remove_component!(sys_144bus, area_old)
remove_component!(sys_144bus, load_zone_old)

#MAKE DEEPCOPIES 
batt_gfm_new = deepcopy(batt_gfm_old)
gfm_new = deepcopy(gfm_old)
batt_gfl_new = deepcopy(batt_gfl_old)
gfl_new = deepcopy(gfl_old)
gen_new = deepcopy(gen_old)
thermal_standard_new = deepcopy(thermal_standard_old)
transformer_2w_new=  deepcopy(transformer_2w_old)
arc_new = deepcopy(arc_old)
b1_new= deepcopy(b1_old)
b2_new= deepcopy(b2_old)
area_new = deepcopy(area_old)
load_zone_new = deepcopy(load_zone_old)

#SET BUS FOR NEW DEVICES  
set_bus!(thermal_standard_new, b2_new)
set_bus!(batt_gfl_new, b2_new)
set_bus!(batt_gfm_new, b2_new)

#ADD TO NEW SYSTEM 
add_component!(sys_2bus, area_new)
add_component!(sys_2bus, load_zone_new)
add_component!(sys_2bus, b1_new)
add_component!(sys_2bus, b2_new)
add_component!(sys_2bus, arc_new)
add_component!(sys_2bus, transformer_2w_new)
add_component!(sys_2bus, thermal_standard_new)
add_component!(sys_2bus, gen_new, thermal_standard_new)
add_component!(sys_2bus, batt_gfl_new)
add_component!(sys_2bus, gfl_new, batt_gfl_new)
add_component!(sys_2bus, batt_gfm_new)
add_component!(sys_2bus, gfm_new, batt_gfm_new)

#MAKE CONNECTING BUS REFERENCE AND ADD SOURCE 
b_connect = get_component(Bus, sys_2bus, "Bus_59")
set_bustype!(b_connect, BusTypes.REF)
s = Source(name="IB", available=true, bus = b_connect, active_power = 0.0, reactive_power= 0.0, R_th = 1e-5, X_th = 1e-5 )
add_component!(sys_2bus, s )

#RUN A SIMULATION 
p = ControlReferenceChange(0.5, gfl_new, :P_ref, 0.6)
sim = Simulation!(MassMatrixModel, sys_2bus, pwd(), (0.0, 10.0), p)
read_initial_conditions(sim)
using OrdinaryDiffEq
execute!(sim, Rodas5(), abstol = 1e-9, reltol = 1e-9)
results = read_results(sim)
#angle = get_state_series(results, ("generator-53-1", :δ));
v = get_voltage_magnitude_series(results, 53)
using Plots
plot(v)
#plot(angle)
##
to_json(sys_2bus,joinpath(pwd(), "PSID2PSCAD", "test", "systems_tests",  "2Bus.json"), force = true)
