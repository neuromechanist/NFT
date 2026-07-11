% utilmesh_check_source_space() - For each source in a source space, compute its
%                      distance to a linear surface mesh and whether it lies inside
%                      that mesh. Used to validate that generated source locations
%                      fall within the (innermost) head-model boundary.
%
% Usage:
%   >> [dim, inm] = utilmesh_check_source_space(so, C, E);
%
% Inputs:
%   so - [M x 3] source-space point coordinates.
%   C  - [Nn x 4] node table of the linear mesh, [index, x, y, z].
%   E  - [Ne x 4] triangle table of the linear mesh, [index, n1, n2, n3].
%
% Outputs:
%   dim - [1 x M] distance of each source to the mesh.
%   inm - [1 x M] logical, true where the source lies inside the mesh.
%
% Author: Zeynep Akalin Acar, SCCN

function [dim, inm] = utilmesh_check_source_space(so,C,E);

hh = waitbar(0,'computing...');
M = size(so,1);
for i = 1 : M
    waitbar(i/M)
    [dm, Pm, el, in] = utilmesh_dist_mesh_point(so(i,:), C, E);
    dim(i) = dm;
    inm(i) = in;
end
close(hh);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

