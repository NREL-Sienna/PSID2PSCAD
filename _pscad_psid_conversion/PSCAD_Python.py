# Matt Bossart
# UPDATED 11/2021 for PSCAD Version 5

import mhi.pscad
import os
import logging
import math
import sys
import time
import win32com.shell as win32
import numpy as np


def update_parameter_by_dictionary(component, d):
    component.parameters(**d)

def update_parameter_by_name(component, name, value):
    params = component.parameters()
    params[name] = value
    component.parameters(**params)

""" def Update_Initial_Condition_Names(inv_handle):
    params = inv_handle.get_parameters()
    inv_name = params["Name"]
    for key in params:
        if "x0" in key:
            params[key] = inv_name + "_" + key
    inv_handle.set_parameters(**params)
 """
def basic_pscad_startup():
    #Get path of directory of the python script, set as working directory
    #path = os.path.dirname(os.path.abspath(__file__))
    #os.chdir(path)

    # Error flag, simulation won't execute if this is not zero
    ERROR = 0

    # SET UP LOGGING FILE
    if os.path.exists('app.log'):
        logging.shutdown()
        os.remove('app.log')
    logging.basicConfig(level=logging.INFO,
                        format="%(levelname)-8s %(name)-26s %(message)s",filename='app.log')
    # Ignore INFO msgs from automation (eg, mhrc.automation.controller, ...)
    logging.getLogger('mhrc.automation').setLevel(logging.WARNING)
    LOG = logging.getLogger('main') # Set Handle (correct name?)

    #THROWS AN ERROR SECOND TIME YOU RUN IT, NOT SURE WHY!!
    versions = mhi.pscad.versions()

    LOG.info("PSCAD Versions: %s", versions)

    # Skip any 'Alpha' versions, if other choices exist
    vers = [ver for ver in versions if 'Alpha' not in ver]
    if len(vers) > 0:
        versions = vers

    # Skip any 'Beta' versions, if other choices exist
    vers = [ver for ver in versions if 'Beta' not in ver]
    if len(vers) > 0:
        versions = vers

    # Skip any 32-bit versions, if other choices exist
    vers = [ver for ver in versions if 'x86' not in ver]
    if len(vers) > 0:
        versions = vers

    LOG.info("   After filtering: %s", versions)

    # Of any remaining versions, choose the "lexically largest" one.

    version, x64 = sorted(versions)[-1]
    LOG.info("   Selected PSCAD version: %s %d-bit", version, 64 if x64 else 32)

    # Get all installed FORTRAN compiler versions
    fortrans = mhi.pscad.fortran_versions()
    LOG.info("FORTRAN Versions: %s", fortrans)

    # Skip 'GFortran' compilers, if other choices exist
    vers = [ver for ver in fortrans if 'GFortran' not in ver]
    if len(vers) > 0:
        fortrans = vers

    LOG.info("   After filtering: %s", fortrans)

    # Order the remaining compilers, choose the last one (highest revision)
    fortran = sorted(fortrans)[-1]
    LOG.info("   Selected FORTRAN version: %s", fortran)

    # Launch PSCAD
    LOG.info("Launching: %s  FORTRAN=%r", version, fortran)
    settings = { 'fortran_version': fortran }
    pscad = mhi.pscad.launch(minimize=True, version=version, x64=x64,
                            settings=settings)

    if not pscad:
        ERROR += ERROR
        LOG.info("PSCAD Failed to Launch")
    LOG.info("PSCAD launched successfully!!!")
    return pscad
    

#DON"T USE ANYTHING BELOW HERE

def Set_Project_Settings(workspace, LOG, cases, settings_proj):
    for case in cases:
        project = workspace.project(case['name']) # Establish namespace handle
        project.focus()
        # project.clean() Can't clean if trying to run from a snapshot!!
        LOG.info('Namespace %s is loaded!' % case['name'])
        params = project.parameters()
        project.set_parameters(time_duration=settings_proj['time_duration'])
        project.set_parameters(time_step=settings_proj['time_step'])
        # Add path to the snapshot startup file, assuming exists in fortran directory in main path directory
        # Attaches snapstart_suffix
        if settings_proj['StartType'] == 1:
            snap_path = os.path.join(path,case['name'] + '.gf42',case['name'] + snapstart_suffix)
            if os.path.exists(snap_path):
                project.set_parameters(startup_filename=snap_path)
                project.set_parameters(StartType=settings_proj['StartType'])
            else:
                project.set_parameters(StartType=0)
                LOG.info('Snapshot file for %s DNE.' % case['name'])
                ERROR += 1
        # Create channel output file name, stored in (namespace).gf42 directory, with channel_suffix added
        project.set_parameters(PlotType=settings_proj['PlotType'])
        if settings_proj['PlotType'] == 1:
            channel_path = case['name'] + settings_proj['channel_suffix']
            project.set_parameters(output_filename=channel_path)

        # Create snap save file name, stored in (namespace).gf42 directory, with snap_suffix added
        project.set_parameters(SnapType=settings_proj['SnapType'])
        if settings_proj['SnapType'] == 1:
            snapsave_file = case['name'] + snapshot_suffix
            project.set_parameters(snapshot_filename=snapsave_file)
            project.set_parameters(SnapTime=settings_proj['SnapTime'])


# Returns a list of the workspace libraries
def Get_Librarys(workspace_hand):
    projects = workspace_hand.projects()
    libs = [prj for prj in projects if prj['type'] == 'Library']
    return libs

# Return list of case handles
# Provides name list as well if names = True
def Get_Cases(workspace_hand,names=False):
    projects = workspace_hand.projects()
    cases = [prj for prj in projects if prj['type'] == 'Case']
    case_handles = []
    for case in cases:
        case_handles.append(workspace_hand.project(case['name']))
    if names:
        return case_handles, cases
    else:
        return case_handles

def Get_Case(workspace_hand, case_name):
    projects = workspace_hand.projects()
    case = [prj for prj in projects if (prj['type'] == 'Case' and prj['name'] == case_name)]
    case_handle = workspace_hand.project(case['name'])
    return case

def Get_Modules(canvas_handle):
    # Finds all modules in canvas_handle, skips over Tlins and Cables
    # Returns list of module handles
    components = canvas_handle.find_all()
    modules = []
    if components != []:
        for comp in components:
            try:
                if comp.is_module() == True:
                    modules.append(comp)
            except Exception:
                pass
    else:
        print('No modules on this canvas.')
    return modules

def Is_Component(canvas_handle,comp_name):
    # Checks the canvas_handle for a component by comp_name
    # Returns list of all component handles with that name
    desired_components = []
    components = canvas_handle.find_all()
    for comp in components:
        try:
            comp_def = comp.get_definition()
            if comp_def.name == comp_name:
                desired_components.append(comp)
        except Exception:
            pass
    return desired_components

def Get_Case_Canvases(workspace_handle):
    # Walks through all cases in workspace, and finds modules with canvases (and library defs too)
    # Only finds canvases established in namespaces, not those in librarys
    # Note, this will only step into modules from the main page (i.e. single step)
    # Note, don't use scoped name! It's possible to establish a handle for a non-existent canvas
    cases = Get_Cases(workspace_handle)
    canvases = []
    for case in cases:
        temp_can = case.user_canvas('main')
        canvases.append(temp_can)
        modules = Get_Modules(temp_can)
        if modules != []:
            for mod in modules:
                mod_def = mod.get_definition()
                canvases.append(case.user_canvas(mod_def.name))
    return canvases

def Generator_Canvases(canvas_handles,gen_keyword):
    # Takes the previously created set of canvas handles and collects only generator modules
    gens = []
    for canvas in canvas_handles:
        if gen_keyword in canvas.name:
            gens.append(canvas)
    return gens

def Update_Gen_Init(gen_handle,workspace,settings):
    # Takes a generator canvase handle (assumed to be an Etran initialization block) and a dict of settings
    # Settings are assumed to be 'Volts', 'Phase', 'P', 'Q'
    proj_name = gen_handle._scope['project']
    proj = workspace.project(proj_name)
    proj.focus()
    # Layer Management
    if settings['Online']:
        proj.set_layer(settings['Name'],'enabled')
        print('Generator %s online, enabled layer.' % settings['Name'])
    if not settings['Online']:
        proj.set_layer(settings['Name'],'disabled')
        print('Generator %s offline, disabled layer.' % settings['Name'])
        return 0

    # Update Init Block Parameters
    init_block = Find_All_Components(gen_handle,'Electranix_Init_Conditions')
    if len(init_block) != 1:
        print('Multiple/no Init Blocks in %s, cannot continue.' % gen_handle.name)
        return 1
    init_block[0].set_parameters(Volts=settings['Volts'],Phase=settings['Phase'],P=settings['P'],Q=settings['Q'])

    # Verify Settings
    parms = init_block[0].get_parameters()
    print('Generator %s updated to V: %0.3f, Ph: %0.3f, P: %0.3f, Q: %0.3f.' % (settings['Name'],float(parms['Volts']),float(parms['Phase']),float(parms['P']),float(parms['Q'])))
    return 0

def Gen_Dispatch(gen_handles,workspace,settings):
    gen_set_count = len(settings)
    gen_model_count = len(gen_handles)

    # Verify consistent number of settings provided with gens in model
    if gen_set_count != gen_model_count:
        print('Inconsistent number of generator settings vs. in model. Cannot proceed.')
        return 1

    # March through and change generator settings
    success = 0
    for gen_set in settings:
        for gen_handle in gen_handles:
            if gen_set['Name'] == gen_handle._scope['definition']:
                result = Update_Gen_Init(gen_handle,workspace,gen_set)
                success += result

    if success == 0:
        print('Successfully adjusted dispatch at %r generators.' % gen_set_count)
        return 0
    elif success != 0:
        print('Incomplete settings adjustment, will not continue.')
        return 1

def Find_All_Components(canvas_handles,comp_name,count=False):
    # Takes list of canvas_handles, or single object handle
    # Checks each for the component with comp_name
    # Returns nested list if input is list each canvas captured by a sub level, otherwise, a single list
    components = []
    if isinstance(canvas_handles,list):
        for canvas in canvas_handles:
            try:
                components.append(Is_Component(canvas,comp_name))
            except Exception:
                pass
    else:
        try:
            components = Is_Component(canvas_handles,comp_name)
        except Exception:
            pass
    return components

def Total(comp_sets,parm_name):
    # Sums the string to float values of the selected parm_name
    total = 0
    quantity = 0
    if any(isinstance(i,list) for i in comp_sets):
        comp_sets = flatten(comp_sets)
    for comp in comp_sets:
        parm = comp.get_parameters()
        total += float(parm[parm_name])
        quantity += 1
    return total, quantity

def Get_Total(canvas_handles,comp_name,parm_name):
    # Single Call total, finds components and sums values
    comp_sets = Find_All_Components(canvas_handles,comp_name)
    return Total(comp_sets,parm_name)


def Current_Settings(canvas_handles,comp_name,parm_name,save_file=True):
    # Collects handles for all comp_names in canvas_handles
    # Generally hard coded for P/Q settings
    # collects bus number (assuming largest number in name), and relavant parm value, in np array
    # defaults to save, returns array if save_file = False
    temp_sets = flatten(Find_All_Components(canvas_handles,comp_name))
    comp_sets = list(filter(None,temp_sets))
    quant = len(comp_sets)
    data = np.empty([quant,2])
    i = 0
    for comp in comp_sets:
        parm = comp.get_parameters()
        name = parm['Name'].split('_')
        nums = [num for num in name if num.isdigit()]
        bus = max(nums)
        data[i,0] = int(bus)
        data[i,1] = float(parm[parm_name])
        i += 1

    if save_file:
        save_header = comp_name + ', ' + parm_name
        save_name = comp_name + '_' + parm_name + '.csv'
        np.savetxt(save_name, data, delimiter=",",header = save_header)
    else:
        return data

def Add_Paired_Signal(canvas_handle,comp,comp_parm,x_pos,y_pos,output_channel=True):
    # Add signal paired to comp_parm of comp handle
    # Grid is 17.5 x 17.5 points
    parms = comp.get_parameters()
    if parms['Name'] != '':
        signal_name = parms[comp_parm]
        new_signal = canvas_handle.add_component('master','datalabel',x_pos,y_pos)
        new_signal.set_parameters(Name=signal_name)
        if output_channel:
            pgb = canvas_handle.add_component('master','pgb',x_pos,y_pos)
            pgb.set_parameters(UseSignalName=1)
        return new_signal, pgb


def Add_Signals(canvas_handle,comp_name,comp_parm,per_row,init_x,init_y,x_spacing,y_spacing,layer,add_layer=False):
    # Add signals (and channels) iteratively for all comp_names on canvas paired with comp_parm
    # puts all channels on a layer if add_layer=True # layer must exist!
    # Grid is 17.5 x 17.5 points: x_spacing/y_spacing is number of point spacing between installs

    comps = Find_All_Components(canvas_handle,comp_name)
    count = len(comps)
    for i in range(0,count):
        x_pos = init_x + ( ( i % per_row ) * (17.5 * x_spacing) )
        y_pos = init_y + ( (17.5 * y_spacing) * math.floor(i/per_row) )
        signal, channel = Add_Paired_Signal(canvas_handle,comps[i],comp_parm,x_pos,y_pos)
        if add_layer:
            signal.add_to_layer(layer)
            channel.add_to_layer(layer)


def Change_Load(canvases,scale_existing=True,scale_val=1.0,load_file=''):
    # Takes a .csv and changes all loads in the file. Reports back on initial and final values
    # scale_existing> True will simply scale the existing load values by the scale_val
    # scale_existing> False will take provided load values, and change the loads and scale according to scale_val
    # Maintains
    load_handles = Find_All_Components(canvases,'Load_Wrapper') # For PSCAD
    # load_handles = Find_All_Components(canvases,'Electranix_Load') # For Etran loads
    if any(isinstance(i,list) for i in load_handles):
        load_handles = flatten(load_handles)

    # Finds initial values of the system
    Real = Total(load_handles,'PO')
    Reactive = Total(load_handles,'QO')
    PF = Real[0] / (Real[0]**2 + Reactive[0]**2)**(1/2)
    print('Initial totals are %0.3f MW, and %0.3f Mvar' % (Real[0],Reactive[0]))
    print('Initial system power factor is %0.3f' % PF)

    if scale_existing == True:
        new_real = 0
        new_reactive = 0
        # Move through and change all loads proportionally. Maintains power factor for reactive set points
        for load in load_handles:
            parm = load.get_parameters()
            Pcur = float(parm['PO'])
            Qcur = float(parm['QO'])
            # I think I don't have to do this with the power factor, can just equally scale
            #pf = Pcur / (Pcur**2 + Qcur**2)**(1/2)
            Ptemp = Pcur * scale_val
            new_real += Ptemp
            #parity = 1
            #if Qcur < 0:
            #    parity = -1
            #Qtemp = round(parity * Ptemp * ((1/(pf**2)) - 1)**(1/2),4)
            Qtemp = Qcur * scale_val
            new_reactive += Qtemp
            load.set_parameters(PO=str(Ptemp),QO=str(Qtemp))
        # Verify Change
        New_Real = Total(load_handles,'PO')
        New_Reactive = Total(load_handles,'QO')
        New_PF = New_Real[0] / (New_Real[0]**2 + New_Reactive[0]**2)**(1/2)
        if round(New_Real[0],1) == round(new_real,1):
            print('All loads scaled from existing values. New totals are %0.3f MW, and %0.3f Mvar. \n Scaling factor implemented is %0.3f.'
            % (New_Real[0],New_Reactive[0],float(New_Real[0]/Real[0])))
            print('New system power factor is %0.3f.' % New_PF)
            return 0
        else:
            print('Implementation was not correct, real power not set correctly.')
            return 1

    # This portion needs to be written!
    elif scale_existing == False:
        try:
            load_data = np.genfromtxt(load_file,delimiter = ',',skip_header=1)
            initial_load_count = load_data.shape
            # Compares the quantity of loads in the file to those in system
            if initial_load_count[0] == Real[1]:
                print('Quantities match.')
        except Exception:
            print('Load file DNE. Cannot perform task')
            exit()




####-----------------
#---Specific Functions
####-----------------


def Change_Parameters(components,new_setting):
    # Changes parameters of components. Still haven't figured out how to pass keyword for set_parameters through function
    comp_handles = flatten(components)
    for comp in comp_handles:
        comp.set_parameters(Pscale_sel=new_setting)

def Delete_Signal_Name(components):
    # Changes parameters of components. Still haven't figured out how to pass keyword for set_parameters through function
    comp_handles = flatten(components)
    for comp in comp_handles:
        parms = comp.get_parameters()
        if parms['Name'] == 'TypTr2_0004_to_0009':
                comp.set_parameters(Name='')


def Add_Load_PQ_Signal_Names(comp_sets):
    # Adds real and reactive power output labels for all of the comps
    # Hard coded to operate with Etran loads, and add name based on bus number
    # Amended hard code to add dg to P and Q of DG loads
    for comps in comp_sets:
        for comp in comps:
            parms = comp.get_parameters()
            name_pieces = parms['P_out'].split('_')
            real_label = 'Pdg_' + name_pieces[1] + '_' + name_pieces[2]
            reactive_label = 'Qdg_' + name_pieces[1] + '_' + name_pieces[2]
            current_label = 'Idg_' + name_pieces[1] + '_' + name_pieces[2]
            voltage_label = 'Vdg_' + name_pieces[1] + '_' + name_pieces[2]
            comp.set_parameters(P_out=real_label,Q_out=reactive_label,voltage_out=voltage_label,current_out=current_label)

def OpenUnpack(file):
    # Hardcoded to extract all bus load data from file 'DayMin_Load'
    temp_file = open(file,'r+')
    bus_data = []
    temp_file.readline()
    for line in temp_file:
        line_data = line.split(',')
        temp_volt = line_data[1].split(' ')
        bus_data.append({'Bus':line_data[0], 'Voltage':temp_volt[-1], 'P':line_data[3], 'Q':line_data[4].strip('\n')})
    return bus_data

def UpdatePSCADFixed(bus_file_name,canvases):
    bus_data = OpenUnpack(bus_file_name)
    loads = flatten(Find_All_Components(canvases,'Load_Wrapper'))
    count = 0
    for load in loads:
        parms = load.get_parameters()
        found = 0
        for bus in bus_data:
            name = 'Wload_' + bus['Bus']
            if parms['Name'] == name:
                found = 1
                P_monitor = 'Pload_' + bus['Bus']
                Q_monitor = 'Qload_' + bus['Bus']
                new_P = str(round(float(bus['P']) / 3,4))
                new_Q = str(round(float(bus['Q']) / 3,4))
                LG_volt = str(round(float(bus['Voltage']) / (3**(1/2)),5))
                load.set_parameters(PO=new_P,QO=new_Q,V_LG=LG_volt,P_out=P_monitor,Q_out=Q_monitor)#,dPdF=2.0,dPdV=1.0)
                #load.set_parameters(T_measure=0.01)
        if found == 1:
            print('Found load %s' % parms['Name'])

            count += 1
    New_Real = Total(loads,'PO')
    New_Reactive = Total(loads,'QO')
    print('Updated the parameters at %r loads.' % count)
    print('New Real is %r, new reactive is %r.' % (New_Real[0], New_Reactive[0]))

#----------------
#### Borrowed Code
#----------------

# Following taken from
# https://stackoverflow.com/questions/16176742/python-3-replacement-for-deprecated-compiler-ast-flatten-function
def flatten(lst):
    """Flattens a list of lists"""
    return [subelem for elem in lst
                    for subelem in elem]

def recursive_len(item):
    if type(item) == list:
        return sum(recursive_len(subitem) for subitem in item)
    else:
        return 1
