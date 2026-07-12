function compact = calc_compactness(pot, An, vr, flag, geodis)
% Cr, Er : cortical mesh
% An = area mesh nodes
% pot: cortical source
% vr: voxel_position

% Copyright (C) Zeynep Akalin Acar, SCCN, zeynep@sccn.ucsd.edu
% Contributor: Seyed Yahya Shirazi, SCCN, INC, UCSD, 07/2026 (extracted into a
%   shared function from the DSL inverse solver; algorithm unchanged)
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

%flag = 0; % Cheng's method
%flag = 1; % Zunic's Kst
%flag = 2; % my area method
if nargin < 5
    geodis = [];
end

An  = An(:); An = An';
if flag == 0
    k = 0.1;
    max_pot = max(abs(pot));

    ind_large_value = find(abs(pot) > max_pot/10);

    number_main_voxel = length(ind_large_value);
    if  number_main_voxel > 0.05*length(pot)
        compact = inf;
    else
        compact = 0;
        for i = 1:number_main_voxel-1
            for j = i+1:number_main_voxel
                te = exp(k*norm(vr(ind_large_value(j),:)-vr(ind_large_value(i),:)));
                compact = compact + abs(pot(ind_large_value(i))/max_pot) * abs(pot(ind_large_value(j))/max_pot) * te;
            end
        end
        compact = compact / (number_main_voxel*number_main_voxel);
    end
end



if flag == 3
    k = 0.1;
    max_pot = max(abs(pot));

    ind_large_value = find(abs(pot) > max_pot/10);

    number_main_voxel = length(ind_large_value);
    if  number_main_voxel > 0.05*length(pot)
        compact = inf;
    else
        compact = 0;
        for i = 1:number_main_voxel-1
            for j = i+1:number_main_voxel
                if i > j
                    dist = geodis(i,j);
                else
                    dist = geodis(j,i);
                end
                if dist == 0
                    dist = 1000;
                end
                if i == j
                    dist = 0;
                end
                te = exp(k * dist);
                compact = compact + abs(pot(ind_large_value(i))/max_pot) * abs(pot(ind_large_value(j))/max_pot) * te;
            end
        end
        compact = compact / (number_main_voxel*number_main_voxel);
    end
end

if flag == 1
    % Compactness measure for 3D shapes
    % J Zunic, K. Hirota, C. Martinez-Ortiz, 2012
    pot = abs(pot);
      if max(pot) == 0
          compact = 0;
          return
      end

    pot = pot / max(pot) * 100; % max =100

    max_pot = max(abs(pot));
    bl = 10;
    ind_large_value = find(abs(pot) > max_pot/bl);
    while length(ind_large_value) < 2
        bl = bl*2;
        ind_large_value = find(abs(pot) > max_pot/bl);
    end
    number_main_voxel = length(ind_large_value);
    pot = abs(pot);
    %if  number_main_voxel > 0.05*length(pot)
        %compact = inf;
    %else
        vol_S = sum(An(ind_large_value).*pot(ind_large_value));
        surf_S = sum(An(ind_large_value));
        compact = 36 * pi * vol_S^2 / surf_S^3;
    %end
    compact = compact/max(pdist(vr(ind_large_value,:)));
end



if flag == 2
    pot = abs(pot);
    if max(pot) == 0
          compact = 0;
          return
      end
    pot = pot / max(pot) * 100; % max =100
    ap  = round(prctile(pot,99));
    if ap < 1; ap = 1; end
    ni = find(pot > ap);
    clear ai ao
    for i = ap:100

        ni = find(pot > i);
        ai(i) = sum(An(ni));
        ao(i) = sum(An(ni) .* pot(ni));
    end
    k = find(ao>std(ao)); jk = max(k)+1;
    compact = (1-ao(jk)/ao(ap)) * 100;
end
