% nft_segmentation() - Headless MRI segmentation: anisotropic filtering, scalp,
% brain, outer-skull, and inner-skull segmentation from an Analyze-format MRI
% volume. This is the scriptable equivalent of the Segmentation GUI's Run
% button, driven straight through its five CurrentOperation steps in order.
%
% Usage:
%   >> nft_segmentation(subject_name, of, mr_file);
%   >> Segm = nft_segmentation(subject_name, of, mr_file, 'Key1', Value1, ...);
%
% Inputs:
%   subject_name : subject name; output files are named '<subject_name>_segments.mat'
%                  and '<subject_name>_mri.mat'
%   of           : output folder where the segmentation outputs are saved
%   mr_file      : path to the Analyze-format MRI, with or without the .hdr
%                  extension (a matching .img must sit next to it). The volume
%                  must be isotropic and cubic (1 mm, K==L==M); this is exactly
%                  what Freesurfer pre-processing produces, and is enforced with
%                  the same check the GUI's file-open step uses.
%
% Optional keywords (defaults match the Segmentation GUI's own default fields;
% sli/WMp/sl/st/sli_eyes are picked in the GUI by visually inspecting the
% subject's own slices, so treat these defaults as generic starting points, not
% as subject-independent constants):
%
%   iter   : number of anisotropic-filtering iterations (default = 5)
%   ts     : anisotropic-filtering time step (default = 0.0625, the value the
%            GUI hardcodes -- its own time-step field is disabled/unused)
%   cond   : anisotropic-filtering diffusion parameter (default = 3)
%   sli    : lowest slice for cerebellum, used by brain segmentation
%            (default = 66)
%   WMp    : 1x3 white-matter seed point [x y z], used by brain and inner-skull
%            segmentation (default = [135 135 110])
%   sl     : watershed fill level for brain segmentation (default = 0.4)
%   st     : watershed threshold for brain segmentation (default = 0.4)
%   sli_eyes : slice used to mark the eyes for outer-skull segmentation
%            (default = 110). segm_outer_skull() opens a figure and calls
%            ginput(2) on this slice to mark the eyes interactively -- this
%            step requires a real graphical MATLAB session (not `matlab -batch`
%            or a headless/no-display host); see segm_outer_skull.m.
%   LRflip : [0 or 1] flip the volume left-right before segmenting, to correct
%            for the flip introduced during MR acquisition (default = 0)
%   CheckInhomogeneity : [0 or 1] run segm_inhomogeneity_correction() on the
%            volume's middle slice first and warn (not error) if its estimated
%            bias-field variance exceeds 0.06, matching the GUI's "Check
%            inhomogeneity" button. This is a diagnostic only -- its result is
%            not saved and does not feed into segmentation -- so it is off by
%            default to keep a scripted run fast and deterministic (default = 0)
%
% Outputs:
%   Segm : segmentation structure with fields scalpmask, brainmask,
%          outerskullmask, innerskullmask (each in the axial orientation
%          nft_mesh_generation() and downstream steps expect) and parameters
%          (MRfile, MRpath, LRflip, filter, brain, skull). Also written to
%          '<of>/<subject_name>_segments.mat' as variable 'Segm', matching
%          exactly what Segmentation.m's "Save segmentation" button produces --
%          nft_mesh_generation() loads this file by that same name. The
%          filtered, normalized MRI is separately written to
%          '<of>/<subject_name>_mri.mat' as variable 'mri', matching
%          Segmentation.m's "Save filtered" button; test_script.m's
%          EEG.dipfit.mrifile wiring reads this same file.
%
% Author: Zeynep Akalin Acar, SCCN, 2008
% Contributor: Seyed Yahya Shirazi, SCCN, INC, UCSD, 07/2026

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

function Segm = nft_segmentation(subject_name, of, mr_file, varargin)

if nargin < 3
    error('NFT:segmentation:args', ...
        'nft_segmentation requires subject_name, of, and mr_file.');
end
if ~ischar(subject_name) || isempty(subject_name)
    error('NFT:segmentation:args', 'subject_name must be a non-empty string.');
end
if ~ischar(of) || isempty(of)
    error('NFT:segmentation:args', 'of (output folder) must be a non-empty string.');
end
if exist(of, 'dir') ~= 7
    error('NFT:segmentation:outputFolder', 'Output folder does not exist: %s', of);
end
if ~ischar(mr_file) || isempty(mr_file)
    error('NFT:segmentation:args', 'mr_file must be a non-empty string.');
end

% default values (match Segmentation.fig's own default field values)
iter = 5;
ts = 0.0625;
cond = 3;
sli = 66;
WMp = [135 135 110];
sl = 0.4;
st = 0.4;
sli_eyes = 110;
LRflip = 0;
check_inhomogeneity = 0;

for i = 1:2:length(varargin) % for each Keyword
    Keyword = varargin{i};
    if i + 1 > length(varargin)
        error('NFT:segmentation:args', 'Keyword "%s" is missing its value.', Keyword);
    end
    Value = varargin{i+1};

    if ~ischar(Keyword)
        error('NFT:segmentation:args', 'Keywords must be strings.');
    end

    switch Keyword
        case 'iter'
            iter = Value;
        case 'ts'
            ts = Value;
        case 'cond'
            cond = Value;
        case 'sli'
            sli = Value;
        case 'WMp'
            if numel(Value) ~= 3
                error('NFT:segmentation:args', 'WMp must be a 1x3 vector [x y z].');
            end
            WMp = Value;
        case 'sl'
            sl = Value;
        case 'st'
            st = Value;
        case 'sli_eyes'
            sli_eyes = Value;
        case 'LRflip'
            LRflip = Value;
        case 'CheckInhomogeneity'
            check_inhomogeneity = Value;
        otherwise
            error('NFT:segmentation:args', 'Unknown keyword: %s', Keyword);
    end
end

of = append_filesep(of);

% --- load the MR volume (mirrors Segmentation.m's OpenMenuItem_Callback) ---
[mr_dir, mr_base, mr_ext] = fileparts(mr_file);
if isempty(mr_ext)
    mr_ext = '.hdr';
end
mr_hdr_name = [mr_base mr_ext];
if isempty(mr_dir)
    mr_dir = pwd;
end
mr_dir = append_filesep(mr_dir);
mr_stub = [mr_dir mr_base];

[volume, pixdim] = segm_readanalyze(mr_stub);
[K, L, M] = size(volume);
if ~(K == L && L == M && M == K && pixdim(1) == 1 && pixdim(2) == 1 && pixdim(3) == 1)
    error('NFT:segmentation:volumeShape', ...
        ['MRI volume is not a cubic, 1 mm isotropic scan. Please run Freesurfer ', ...
         'pre-processing on the MR image: ', ...
         'https://sccn.ucsd.edu/wiki/Chapter_02:_Head_Modeling_from_MR_Images']);
end

if LRflip
    % flip image left-right (image is flipped during MR acquisition); image is
    % sagittal at this point
    volume_flipped = zeros(K, L, M);
    for i = 1:M
        volume_flipped(:, :, i) = volume(:, :, M - i + 1);
    end
    volume = volume_flipped;
    clear volume_flipped;
end

if check_inhomogeneity
    I0 = volume(:, :, round(M / 2));
    [B, ~, ~, ~] = segm_inhomogeneity_correction(I0);
    if var(B(:)) > 0.06
        warning('NFT:segmentation:inhomogeneity', ...
            ['Inhomogeneity in this image may result in incorrect segmentation. ', ...
             'Consider loading a corrected volume (see the NFT manual for Freesurfer ', ...
             'inhomogeneity correction).']);
    end
end

% matitk (a MEX file, not one of the nft_get_config-dispatched binaries) backs
% the anisotropic filtering, scalp, and brain segmentation steps below. Fail
% loudly with an actionable message rather than letting MATLAB raise an opaque
% "Undefined function" partway through the run -- matitk currently ships
% mexa64/mexw64/mexmaci64 only, so it is Undefined on Apple Silicon (maca64).
% Checked here, immediately before the first matitk-dependent call, rather than
% at entry, so that platform-independent steps above (volume load/validation,
% LRflip, the optional inhomogeneity check) still work on a matitk-less host.
if exist('matitk', 'file') ~= 3
    error('NFT:segmentation:matitkMissing', ...
        ['matitk MEX function not found for this platform (%s). Segmentation ', ...
         'depends on matitk for anisotropic filtering, scalp, and brain steps. ', ...
         'See AGENTS.md known-broken notes (no mexmaca64 build yet).'], computer('arch'));
end

% --- main segmentation flow (mirrors Segmentation.m's Runbutton_Callback,
% CurrentOperation 1..5, in order) ---
disp('Filtering...');
filteredvol = segm_aniso_filtering(volume, iter, ts, cond);

disp('Segmenting scalp...');
scalpmask = segm_scalp(filteredvol);

disp('Segmenting brain...');
brainmask = segm_brain(filteredvol, scalpmask, sli, WMp, sl, st);

disp('Segmenting outer skull...');
fprintf(['Note: segm_outer_skull() opens a figure and calls ginput(2) to mark ', ...
    'the eyes on slice %d -- this requires an interactive graphical MATLAB ', ...
    'session, not `matlab -batch` or a display-less host.\n'], sli_eyes);
[outerskullmask, X_dark, thr] = segm_outer_skull(filteredvol, scalpmask, brainmask, sli_eyes);

disp('Segmenting inner skull...');
innerskullmask = segm_inner_skull(filteredvol, outerskullmask, X_dark, brainmask, WMp);

disp('Correcting skull and scalp...');
[scalpmask, outerskullmask] = segm_final_skull(scalpmask, outerskullmask, innerskullmask, WMp);

% --- assemble the parameters struct (mirrors what the GUI accumulates into
% handles.parameters as each step runs) ---
parameters.MRfile = mr_hdr_name;
parameters.MRpath = mr_dir;
parameters.LRflip = LRflip;
parameters.filter.iter = iter;
parameters.filter.cond = cond;
parameters.brain.slice = sli;
parameters.brain.WMp = WMp;
parameters.brain.filllevel = sl;
parameters.brain.threshold = st;
parameters.skull.sli_eyes = sli_eyes;
parameters.skull.thr = thr;

Segm.scalpmask = sagittal_to_axial(scalpmask);
Segm.brainmask = sagittal_to_axial(brainmask);
Segm.outerskullmask = sagittal_to_axial(outerskullmask);
Segm.innerskullmask = sagittal_to_axial(innerskullmask);
Segm.parameters = parameters;

disp(['Saving segmentation as ' subject_name '_segments.mat']);
save([of subject_name '_segments.mat'], 'Segm');

% --- save the filtered MRI (mirrors Segmentation.m's
% pushbuttonSaveFiltered_Callback; test_script.m wires EEG.dipfit.mrifile to
% this same '<subject>_mri.mat' file) ---
filt_im = sagittal_to_axial(filteredvol);
filt_im = filt_im / max(max(max(filt_im)));
[Kf, Lf, Mf] = size(filt_im);
mri.dim = [Kf Lf Mf];
mri.xgrid = 1:Kf;
mri.ygrid = 1:Lf;
mri.zgrid = 1:Mf;
mri.anatomy = filt_im;
mri.transform = eye(4);
mri.hdr = mr_hdr_name;

disp(['Saving filtered image as ' subject_name '_mri.mat']);
save([of subject_name '_mri.mat'], 'mri');

disp('Segmentation complete!');


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function path = append_filesep(path)
len = length(path);
if path(len) ~= filesep
    path(len + 1) = filesep;
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function out = sagittal_to_axial(vol)
% Convert a sagittal-orientation volume/mask to the axial orientation that
% saved '_segments.mat'/'_mri.mat' files use, matching the transform
% Segmentation.m's save callbacks apply before writing to disk.
[K, L, M] = size(vol);
out = zeros(K, M, L, class(vol));
for i = 1:M
    out(:, i, :) = reshape(vol(:, :, i), K, L);
end
[~, ~, M2] = size(out);
for i = 1:M2
    out(:, :, i) = rot90(out(:, :, i), 3);
end
if islogical(vol)
    out = logical(out);
end
