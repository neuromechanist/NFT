% ReadSMF() - Read a surface mesh in SMF (Simple Model Format) format, applying a
%             per-axis translation and a scale along z. Vertex lines start with
%             'v'; triangle lines start with 't' or 'f'.
%
% Usage:
%   >> [Coord, Elem] = ReadSMF(name, x, y, z, sc);
%
% Inputs:
%   name - path to the SMF mesh file.
%   x    - translation added to the x coordinate of every node.
%   y    - translation added to the y coordinate of every node.
%   z    - translation added to the (scaled) z coordinate of every node.
%   sc   - scale factor applied to the z coordinate (z_out = z_in/sc + z).
%
% Outputs:
%   Coord - [Nn x 4] node table: [index, x, y, z].
%   Elem  - [Ne x 4] element table: [index, n1, n2, n3].
%
% Author: Zeynep Akalin Acar, SCCN

function [Coord, Elem]=ReadSMF(name,x,y,z,sc);
fid=fopen(name, 'r');
nnp=0; nel=0;
line=1;
while line~=-1
   line=fgets(fid);
    if line(1)=='v';
    nnp=nnp+1;
       [A,count,ERRMSG,NEXTINDEX] = sscanf(line,'%c %f %f %f',4);
    Coord(nnp,1)=nnp;
       Coord(nnp,2:4)=A(2:4)';
    elseif (line(1)=='t')|(line(1)=='f');
    nel=nel+1;
       [A,count,ERRMSG,NEXTINDEX] = sscanf(line,'%c %d %d %d',4);
        Elem(nel,1)=nel;
    Elem(nel,2:4)=A(2:4)';
   end
end
fclose(fid);

Coord(:,4)=Coord(:,4)/sc+z;
Coord(:,2)=Coord(:,2)+x;
Coord(:,3)=Coord(:,3)+y;

