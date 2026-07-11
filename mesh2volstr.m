% mesh2volstr() - Convert an NFT BEM mesh into a DIPFIT/FieldTrip-style volume
%                 conductor structure, splitting the concatenated mesh into one
%                 boundary per layer with local node indexing.
%
% Usage:
%   >> vol = mesh2volstr(mesh);
%
% Inputs:
%   mesh - BEM mesh name or structure (loaded via bem_load_mesh).
%
% Outputs:
%   vol - volume structure with vol.bnd(i).pnt (node coordinates) and
%         vol.bnd(i).tri (triangle indices) for each boundary i.
%
% Author: Zeynep Akalin Acar, SCCN, 2012

function vol = mesh2volstr(mesh)
mesh = bem_load_mesh(mesh);
vol = [];
ncoordp = 0;
nelemp = 0;
for ii = 1:mesh.num_boundaries
    nelem = mesh.bnd(ii,1) + nelemp;
    vol.bnd(ii).tri = mesh.elem(nelemp+1:nelem,:) - ncoordp;
    ncoord = max(max(vol.bnd(ii).tri)) + ncoordp;
    vol.bnd(ii).pnt = mesh.coord(ncoordp+1:ncoord,:);
    ncoordp = ncoord;
    nelemp = nelem;
end
