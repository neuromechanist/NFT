% nft_warping_mesh() - Generated BEM (and FEM) 3- or 4-layer template MNI meshes warped
% to the electrode locations
%
% Usage:
%   >> nft_warping_mesh(subject_name, session_name, elec_file, nl, of, plotting, femmesh)
%
% Inputs:
%   subject_name - subject name as entered in NFT main window
%   session_name - session name as entered in NFT main window
%   of - output folder where all the outputs are saved
%   elec_file - [Optional] electrode file
%   nl - number of layers (3 or 4)
%   plotting - flag to plot meshes
%   femmesh - flag to generate a FEM mesh using the warped BEM mesh
%
%
% Author: Zeynep Akalin Acar, SCCN, 2012

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

function [warpedMNImesh, MNImesh, warping] = nft_warping_mesh(subject_name, session_name, elec_file, nl, of, plotting, femmesh)

  if nargin < 5
     error('not enough arguments');
  end
  if nargin < 6
    plotting = 0;
  end
  if nargin < 7
    femmesh = 0;
  end

  p = append_filesep(of);

  [input_electrodes, eloc] = load_electrodes(elec_file, p);

  [MNImesh, electrodes, fiducials, index_kdm] = init_mesh(input_electrodes, plotting);

  [Ptm, ind, Cscalp_w, Cskull_w, CCSF_w, Cbrain_w, W, A, e, LMm2, ...
   back, Escalp, Eskull, ECSF, Ebrain] = warping_main_function(p, ...
                                   MNImesh.Cscalp, MNImesh.Escalp, ...
                                   MNImesh.Eskull, MNImesh.ECSF, ...
                                   MNImesh.Ebrain, MNImesh.Cskull, ...
                                   MNImesh.CCSF, MNImesh.Cbrain, ...
                                   MNImesh.Landmarks, MNImesh.Fiducials, ...
                                   fiducials, electrodes, index_kdm);

  MNImesh.Escalp = Escalp;
  MNImesh.Eskull = Eskull;
  MNImesh.ECSF = ECSF;
  MNImesh.Ebrain = Ebrain;

  warpedMNImesh.Cscalp = Cscalp_w;
  warpedMNImesh.Cskull = Cskull_w;
  warpedMNImesh.CCSF = CCSF_w;
  warpedMNImesh.Cbrain = Cbrain_w;

%  fitelectrodes = Ptm;
%  chosenindices = ind;

  warping.back=back;
  warping.forward.W = W;
  warping.forward.A = A;
  warping.forward.e = e;
  warping.forward.LMm2 = LMm2;

  if plotting
     figure;

    % convert to linear mesh if it is quadratic
    if size(MNImesh.Escalp,2) == 7
      Elem(:,1:2) = MNImesh.Escalp(:,1:2);
      Elem(:,3) = MNImesh.Escalp(:,4);
      Elem(:,4) = MNImesh.Escalp(:,6);
      np = max(max(Elem(:,2:4)));
      Coord = Cscalp_w(1:np,:);
    else
      Elem = MNImesh.Escalp; Coord = Cscalp_w;
    end

    eeglab_plotmesh(Elem(:,2:4), Coord(:,2:4),[],1); hold; axis on;
    plot3(Ptm(:,1), Ptm(:,2), Ptm(:,3), 'b.')
    axis([-100 100 -200 100 -100 150])
    view(165, 10)
  end

  % save warped sensors and index
  fsubj = subject_name;
  fses = session_name;

  f = [fsubj '_' fses];
  warped_sensors = Ptm;

  %save([p f '_headsensors.sens'], 'warped_sensors', '-ascii');
  %clear warped_sensors;
  %save([p f '_sensorindex'], 'ind', '-ascii'); % save the index, to use in IP

  ssave.fn = elec_file;
  ssave.eloc = eloc;
  ssave.pnt = warped_sensors;
  ssave.ind = ind;
  save([p f '.sensors'], '-STRUCT', 'ssave')

  % save the mesh
  [Coord, Elem] = utilbem_add_mesh(Cscalp_w, MNImesh.Escalp, Cskull_w, MNImesh.Eskull);
  [Coord, Elem] = utilbem_add_mesh(Coord, Elem, CCSF_w, MNImesh.ECSF);
  if nl==4
    [Coord, Elem] = utilbem_add_mesh(Coord, Elem, Cbrain_w, MNImesh.Ebrain);
  end

  save([p fsubj '.bec'], 'Coord', '-ascii');

  Info(1,1) = nl;
  if nl==3
    Info(1,2) = size(MNImesh.Escalp,1)+size(MNImesh.Eskull,1)+size(MNImesh.ECSF,1);
    Info(1,3) = size(Cscalp_w,1)+size(Cskull_w,1)+size(CCSF_w,1);
  elseif nl==4
    Info(1,2) = size(MNImesh.Escalp,1)+size(MNImesh.Eskull,1)+size(MNImesh.ECSF,1)+size(MNImesh.Ebrain,1);
    Info(1,3) = size(Cscalp_w,1)+size(Cskull_w,1)+size(CCSF_w,1)+size(Cbrain_w,1);
    Info(5,1) = 4;
    Info(5,2) = size(MNImesh.Ebrain,1);
    Info(5,3:4) = [4 3];
  end

  Info(1,4) = size(MNImesh.Escalp,2)-1; % number of nodes per element
  Info(2,1) = 1;
  Info(2,2) = size(MNImesh.Escalp,1);
  Info(2,3:4) = [1 0];
  Info(3,1) = 2;
  Info(3,2) = size(MNImesh.Eskull,1);
  Info(3,3:4) = [2 1];
  Info(4,1) = 3;
  Info(4,2) = size(MNImesh.ECSF,1);
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
  warping_param = warping;

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

  if femmesh
    write_FEM(of, subject_name);
  end

%%%%%%%%
function path = append_filesep(path)
  len = length(path);
  if path(len) ~= filesep
    path(len + 1) = filesep;
  end


function [input_electrodes, eloc] = load_electrodes(elocfn, of)

  eloc = readlocs(elocfn);   % subject's electrode locations

  if ~strcmp(eloc(1).type,'FID') || ~strcmp(eloc(2).type,'FID') || ~strcmp(eloc(3).type,'FID')
    error('Electrode file does not contain fiducials! Co-registration is done using the fiducials!')
  end

  if ~strcmp(eloc(1).labels,'Nz')
    if ~strcmp(eloc(1).labels,'fidt9')
      warning('Fiducials are assumed to be in this order: [Nz LPA, RPA].')
      msgbox('Fiducials are assumed to be in this order: [Nz LPA, RPA]','','warn')
    else   % for .sfp files
      eloc2=eloc;
      eloc2(1)=eloc(2);
      eloc2(2)=eloc(1);
      eloc=eloc2;
    end
  end

  sens_fn = elocfn;
  ne = length(eloc);
    elo = zeros(ne, 3);
  for i = 1:ne;
    elo(i,:) = [eloc(i).X eloc(i).Y eloc(i).Z];
  end

  [d, elo] = warping_distafterwarping([0 0 0 0 0 90], elo, elo); % arrange orientation ??? check!


  p = append_filesep(of);
  save([p 'ori_sen_loc'], 'sens_fn'); % save the location of original sensors in mesh folder

  input_electrodes = elo;


% Initialize the template mesh and plot it
function [MNImesh, electrodes, fiducials, index_kdm] = init_mesh(input_electrodes, plotting)

  load Warping_MNIdata4L

  MNImesh.Cscalp = Cscalp;
  MNImesh.Escalp = Escalp;
  MNImesh.Cskull = Cskull;
  MNImesh.Eskull = Eskull;
  MNImesh.CCSF = CCSF;
  MNImesh.ECSF = ECSF;
  MNImesh.Cbrain = Cbrain;
  MNImesh.Ebrain = Ebrain;
  MNImesh.Fiducials = Fm;
  MNImesh.Landmarks = LMm;

  elo = input_electrodes;
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

  if plotting
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

    figure;
    eeglab_plotmesh(Elem(:,2:4), Coord(:,2:4),[],1); hold on; axis on;
    axis([-100 100 -200 100 -100 150])
    view(165, 10)
  end

  [pos, Fd] = initial_registration(elo, elo(1:3,:), Cscalp, Fm);

  % find the index of the electrodes that are close to the scalp
  [elox, dm] = warping_distmeshafterwarping([0 0 0 0 0 0], pos, Cscalp, Escalp);
  mdm = median(dm); sdm = std(dm);
  kdm = find((dm < 2*mdm)); % kdm gives the index of the electrodes close to the scalp
  index = (1:length(pos));
  rejected = setdiff(index,kdm);

  if plotting
    plot3(pos(:,1), pos(:,2), pos(:,3), 'b.')
    plot3(pos(rejected,:),pos(rejected,2),pos(rejected,3),'ro')
  end

  electrodes = pos;
  fiducials = Fd;
  index_kdm = kdm;

function write_FEM(of, mesh_name)
  % load mesh configuration for path names
  conf = nft_get_config;

  of = append_filesep(of); % Output Folder

  fn = [of mesh_name '.bei'];

  if exist(fn, 'file') == 0
    error('BEM mesh not found!')
  end

  mesh = bem_load_mesh([of mesh_name]);
  R = mesh_find_regions(mesh);
  Coord(:,2:4) = mesh.coord;
  Elem(:,2:4) = mesh.elem;
  Coord(:,1) = (1:length(Coord))';
  Elem(:,1) = (1:length(Elem))';

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

  if status ~= 0;
    error('Warping_mesh:system','Failed to execute: %s',result);
  end
