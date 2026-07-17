function varargout = Warping_mesh(varargin)
% WARPING_MESH M-file for Warping_mesh.fig
%      WARPING_MESH, by itself, creates a new WARPING_MESH or raises the existing
%      singleton*.
%
%      H = WARPING_MESH returns the handle to a new WARPING_MESH or the handle to
%      the existing singleton*.
%
%      WARPING_MESH('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in WARPING_MESH.M with the given input arguments.
%
%      WARPING_MESH('Property','Value',...) creates a new WARPING_MESH or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before Warping_mesh_OpeningFunction gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to Warping_mesh_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES
%
% Author: Zeynep Akalin Acar, SCCN, 2008

% Copyright (C) 2007 Zeynep Akalin Acar, SCCN, zeynep@sccn.ucsd.edu
%
% This program is free software; you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation; either version 2 of the License, or
% (at your option) any later version.
%
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
%
% You should have received a copy of the GNU General Public License
% along with this program; if not, write to the Free Software
% Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA


% Edit the above text to modify the response to help Warping_mesh

% Last Modified by GUIDE v2.5 07-Jan-2011 16:03:50

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @Warping_mesh_OpeningFcn, ...
                   'gui_OutputFcn',  @Warping_mesh_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT


% --- Executes just before Warping_mesh is made visible.
function Warping_mesh_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to Warping_mesh (see VARARGIN)

% Parse arguments and set handles as necessary
for i = 1:length(varargin)
    if strcmp(varargin{i}, 'subjectdir')
        i = i + 1;
        handles.MeshFolder = varargin{i};
    elseif strcmp(varargin{i}, 'subject')
        i = i + 1;
        handles.arg_subject = varargin{i};
    elseif strcmp(varargin{i}, 'session')
        i = i + 1;
        handles.arg_session = varargin{i};
    end
end

if isfield(handles,'MeshFolder')
    set(handles.text5, 'String', handles.MeshFolder);
end

% Choose default command line output for Warping_mesh
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);



% --- Outputs from this function are returned to the command line.
function varargout = Warping_mesh_OutputFcn(hObject, eventdata, handles)
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;


% --- Executes on button press in warpingpushbutton.
function warpingpushbutton_Callback(hObject, eventdata, handles)
% hObject    handle to warpingpushbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

of = handles.MeshFolder;

lof = length(of);
if of(lof) ~= '/'
    of(lof+1) = '/';
end

[Ptm, ind, Cscalp_w,Cskull_w,CCSF_w,Cbrain_w,W,A,e,LMm2,back,Escalp,Eskull,ECSF,Ebrain] = warping_main_function(of,handles.MNImesh.Cscalp, ...
    handles.MNImesh.Escalp, handles.MNImesh.Eskull, handles.MNImesh.ECSF, handles.MNImesh.Ebrain,handles.MNImesh.Cskull, handles.MNImesh.CCSF, handles.MNImesh.Cbrain, ...
    handles.MNILandmarks, handles.MNIFiducials, ...
    handles.fiducials, handles.electrodes, handles.index_kdm);

handles.MNImesh.Escalp = Escalp;
handles.MNImesh.Eskull = Eskull;
handles.MNImesh.ECSF = ECSF;
handles.MNImesh.Ebrain = Ebrain;

handles.warpedMNImesh.Cscalp = Cscalp_w;
handles.warpedMNImesh.Cskull = Cskull_w;
handles.warpedMNImesh.CCSF = CCSF_w;
handles.warpedMNImesh.Cbrain = Cbrain_w;
handles.fitelectrodes = Ptm;
handles.chosenindices = ind;
guidata(handles.figure1, handles);

handles.warping.back=back;
handles.warping.forward.W = W;
handles.warping.forward.A = A;
handles.warping.forward.e = e;
handles.warping.forward.LMm2 = LMm2;

axes(handles.axes2);

% convert to linear mesh if it is quadratic
if size(handles.MNImesh.Escalp,2) == 7
    Elem(:,1:2) = handles.MNImesh.Escalp(:,1:2);
    Elem(:,3) = handles.MNImesh.Escalp(:,4);
    Elem(:,4) = handles.MNImesh.Escalp(:,6);
    np = max(max(Elem(:,2:4)));
    Coord = Cscalp_w(1:np,:);
else
    Elem = handles.MNImesh.Escalp; Coord = Cscalp_w;
end

eeglab_plotmesh(Elem(:,2:4), Coord(:,2:4),[],1); hold; axis on;
plot3(Ptm(:,1), Ptm(:,2), Ptm(:,3), 'b.')
axis([-100 100 -200 100 -100 150])
view(165, 10)

% save the electrode locations, and ind
p = handles.MeshFolder;

lof = length(p);
if p(lof) ~= '/'
    p(lof+1) = '/';
end

% save warped sensors and index
if isfield(handles,'arg_subject')
    fsubj = [handles.arg_subject];
else
    fsubj = 'tempSubj';
end
if isfield(handles,'arg_session')
    fses = [handles.arg_session];
else
    fses = 'tempSes';
end
f = [fsubj '_' fses];
warped_sensors = Ptm;
%save([p f '_headsensors.sens'], 'warped_sensors', '-ascii');
%clear warped_sensors;
%save([p f '_sensorindex'], 'ind', '-ascii'); % save the index, to use in IP

ssave.fn = handles.elocfn;
ssave.eloc = handles.eloc;
ssave.pnt = warped_sensors;
ssave.ind = ind;
save([p f '.sensors'], '-STRUCT', 'ssave')

nl = str2num(get(handles.edit_nl, 'String'));
% save the mesh
[Coord, Elem] = utilbem_add_mesh(Cscalp_w, handles.MNImesh.Escalp, Cskull_w, handles.MNImesh.Eskull);
[Coord, Elem] = utilbem_add_mesh(Coord, Elem, CCSF_w, handles.MNImesh.ECSF);
if nl==4
    [Coord, Elem] = utilbem_add_mesh(Coord, Elem, Cbrain_w, handles.MNImesh.Ebrain);
end

save([p fsubj '.bec'], 'Coord', '-ascii');


Info(1,1) = nl;
if nl==3
    Info(1,2) = size(handles.MNImesh.Escalp,1)+size(handles.MNImesh.Eskull,1)+size(handles.MNImesh.ECSF,1);
    Info(1,3) = size(Cscalp_w,1)+size(Cskull_w,1)+size(CCSF_w,1);
elseif nl==4
    Info(1,2) = size(handles.MNImesh.Escalp,1)+size(handles.MNImesh.Eskull,1)+size(handles.MNImesh.ECSF,1)+size(handles.MNImesh.Ebrain,1);
    Info(1,3) = size(Cscalp_w,1)+size(Cskull_w,1)+size(CCSF_w,1)+size(Cbrain_w,1);
    Info(5,1) = 4;
    Info(5,2) = size(handles.MNImesh.Ebrain,1);
    Info(5,3:4) = [4 3];
end
Info(1,4) = size(handles.MNImesh.Escalp,2)-1; % number of nodes per element
Info(2,1) = 1;
Info(2,2) = size(handles.MNImesh.Escalp,1);
Info(2,3:4) = [1 0];
Info(3,1) = 2;
Info(3,2) = size(handles.MNImesh.Eskull,1);
Info(3,3:4) = [2 1];
Info(4,1) = 3;
Info(4,2) = size(handles.MNImesh.ECSF,1);
Info(4,3:4) = [3 2];



fid = fopen([p fsubj '.bei'], 'w');
fprintf(fid, '%d %d %d %d\r\n', Info');
fclose(fid);

if size(Elem,2) == 4
    fid = fopen([p fsubj '.bee'],'w');
    fprintf(fid, '%d %d %d %d\r\n', Elem');
    fclose(fid);
elseif size(Elem,2) ==7
    fid = fopen([p fsubj '.bee'],'w');
    fprintf(fid, '%d %d %d %d %d %d %d\r\n', Elem');
    fclose(fid);
end


% save warping parameters
warping_param = handles.warping;

save([p f '_warping.mat'], 'warping_param'); % save the index, to use in IP

load Warping_so_MNIdata4L

rw = warp_lm(so_MNIdataconv, A, W, LMm2) + so_MNIdataconv;
Ns = size(rw, 1);
so = zeros(3*Ns, 6);
so(1:Ns, 1:3) = rw;
so(1:Ns, 4) = 1;
so(1+Ns:2*Ns, 1:3) = rw;
so(1+Ns:2*Ns, 5) = 1;
so(1+Ns*2:3*Ns, 1:3) = rw;
so(1+Ns*2:3*Ns, 6) = 1;


% save source space
save([p fsubj '_sourcespace.dip'], 'so', '-ascii');


set(handles.warpingpushbutton, 'String', 'Mesh Warped!');
set(handles.warpingpushbutton, 'Enable', 'off');

set(handles.pushbuttonFEM, 'Enable', 'on');
% --------------------------------------------------------------------
function FileMenu_Callback(hObject, eventdata, handles)
% hObject    handle to FileMenu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --------------------------------------------------------------------
function OpenMenuItem_Callback(hObject, eventdata, handles)
% hObject    handle to OpenMenuItem (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


function editFolder_Callback(hObject, eventdata, handles)
% hObject    handle to editFolder (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of editFolder as text
%        str2double(get(hObject,'String')) returns contents of editFolder as a double


% --- Executes during object creation, after setting all properties.
function editFolder_CreateFcn(hObject, eventdata, handles)
% hObject    handle to editFolder (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end




% --- Executes on button press in pushbutton6.
function pushbutton6_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton6 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.MeshFolder = uigetdir;
set(handles.text5, 'String', handles.MeshFolder);
% Update handles structure
guidata(handles.figure1, handles);




% --- Executes on button press in pushbutton7.
function pushbutton7_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton7 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

[file, path] = uigetfile('*.*');  % changed 01-06-2011
handles.elocfn = [path file];
if ~isequal(file, 0) && length(file) > 1
    eloc = readlocs([path file]);   % subject's electrode locations
    handles.eloc = eloc;
    if ~strcmp(eloc(1).type,'FID') | ~strcmp(eloc(2).type,'FID') | ~strcmp(eloc(3).type,'FID')
        error('Electrode file does not contain fiducials! Co-registration is done using the fiducials!')
    end
    if ~strcmp(eloc(1).labels,'Nz')
        if ~strcmp(eloc(1).labels,'fidt9')
            warning('Fiducials are assumed to be in this order: [Nz LPA, RPA].')
            h = msgbox('Fiducials are assumed to be in this order: [Nz LPA, RPA]','','warn')
        else   % for .sfp files
            eloc2=eloc;
            eloc2(1)=eloc(2);
            eloc2(2)=eloc(1);
            eloc=eloc2;
        end

    end
    sens_fn = [path file];
    for i = 1:length(eloc); elo(i,:) = [eloc(i).X eloc(i).Y eloc(i).Z]; end
    [d, elo] = warping_distafterwarping([0 0 0 0 0 90], elo, elo); % arrange orientation ??? check!
    ne = size(elo,1);

    p = handles.MeshFolder; % save the files in mesh folder
    lof = length(p);
    if p(lof) ~= '/';   p(lof+1) = '/'; end;
    save([p 'ori_sen_loc'], 'sens_fn'); % save the location of original sensors
end

handles.input_electrodes = elo;
% set filename removing .elp
handles.filename = file(1:length(file)-4);
handles.filepath = path;

set(handles.warpingpushbutton, 'Enable', 'on');
set(handles.warpingpushbutton, 'String', 'Start Warping');
set(handles.text6,'String',[path file])

updateMeshPlot(handles);

% Update the mesh and plot it
function updateMeshPlot(handles)

nl = str2num(get(handles.edit_nl, 'String'));

load Warping_MNIdata4L

handles.MNImesh.Cscalp = Cscalp;
handles.MNImesh.Escalp = Escalp;
handles.MNImesh.Cskull = Cskull;
handles.MNImesh.Eskull = Eskull;
handles.MNImesh.CCSF = CCSF;
handles.MNImesh.ECSF = ECSF;
handles.MNImesh.Cbrain = Cbrain;
handles.MNImesh.Ebrain = Ebrain;
handles.MNIFiducials = Fm;
handles.MNILandmarks = LMm;

elo = handles.input_electrodes;
a1 = max(elo) - min(elo);
a2 = max(Cscalp(:,2:4)) - min(Cscalp(:,2:4));
rat = mean(a2./a1);
% make the same scale with the mesh
if rat>500
    elo = elo * 1000;
elseif rat>50
    elo = elo * 100;
elseif rat>5
    elo = elo * 10;
end
handles.input_electrodes = elo;



cla(handles.axes1);
axes(handles.axes1);
hold off

% convert to linear mesh if it is quadratic
if size(Escalp,2) == 7
    Elem(:,1:2) = Escalp(:,1:2);
    Elem(:,3) = Escalp(:,4);
    Elem(:,4) = Escalp(:,6);
    np = max(max(Elem(:,2:4)));
    Coord = Cscalp(1:np,:);
else
    Elem = Escalp; Coord = Cscalp;
end

eeglab_plotmesh(Elem(:,2:4), Coord(:,2:4),[],1); hold on; axis on;
axis([-100 100 -200 100 -100 150])
view(165, 10)

if isfield(handles, 'input_electrodes')
    elo = handles.input_electrodes;
    [pos, Fd] = initial_registration(elo, elo(1:3,:), Cscalp, Fm);

    % find the index of the electrodes that are close to the scalp
    [elox, dm] = warping_distmeshafterwarping([0 0 0 0 0 0], pos, Cscalp, Escalp);
    mdm = median(dm); sdm = std(dm);
    kdm = find((dm < 2*mdm)); % kdm gives the index of the electrodes close to the scalp
    index = [1:length(pos)]; rejected = setdiff(index,kdm)


    handles.electrodes = pos;
    handles.fiducials = Fd;
    handles.index_kdm = kdm;
    pos = handles.electrodes;
    plot3(pos(:,1), pos(:,2), pos(:,3), 'b.')
    plot3(pos(rejected,:),pos(rejected,2),pos(rejected,3),'ro')
end

% Update handles structure
guidata(handles.figure1, handles);


% --------------------------------------------------------------------
function uipanel2_SelectionChangeFcn(hObject, eventdata, handles)
% hObject    handle to uipanel2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

updateMeshPlot(handles);


function edit_nl_Callback(hObject, eventdata, handles)
% hObject    handle to edit_nl (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit_nl as text
%        str2double(get(hObject,'String')) returns contents of edit_nl as a double


% --- Executes during object creation, after setting all properties.
function edit_nl_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit_nl (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in pushbuttonFEM.
function pushbuttonFEM_Callback(hObject, eventdata, handles)
% hObject    handle to pushbuttonFEM (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% load mesh configuration for path names
conf = nft_get_config;

of = handles.MeshFolder; % Output Folder
lof = length(of);
if of(lof) ~= filesep
    of(lof+1) = filesep;
end

if isfield(handles,'arg_subject')
    mesh_name = [handles.arg_subject];
else
    mesh_name = 'tempSubj';
end


fn = [of mesh_name '.bei'];

if exist(fn) == 0
    error('BEM mesh not found!')
end

mesh = bem_load_mesh([of mesh_name]);
R = mesh_find_regions(mesh);
Coord(:,2:4) = mesh.coord;
Elem(:,2:4) = mesh.elem;
Coord(:,1) = [1:length(Coord)]';
Elem(:,1) = [1:length(Elem)]';

fn = [of mesh_name '.smesh'];
WriteSMESH(fn, Coord, Elem, R);

% call tetgen
a = sprintf('"%s" -pq1.4a5A "%s"', conf.tetgen, fn);
[status, result] = system(a);
if status ~= 0; error('Warping_mesh:system','Failed to execute: %s',result); end

% convert into metu-fem mesh
nl = mesh.num_boundaries;
if nl == 4
    cnd_str = '1=C1 2=C2 3=C3 4=C4';
elseif nl == 3
    cnd_str = '1=C1 2=C2 3=C3';
end
fn = [of mesh_name '.1'];
a = sprintf('"%s" "%s" %s', conf.tetgen2msh, fn, cnd_str);
[status, result] = system(a);
if status ~= 0; error('Warping_mesh:system','Failed to execute: %s',result); end


set(handles.pushbuttonFEM, 'String', 'FEM mesh generated!');
set(handles.pushbuttonFEM, 'Enable', 'off');
