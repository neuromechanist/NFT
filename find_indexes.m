function [ind_fp, ind_eeg] = find_indexes(EEG, elp_index, eloc);
% realistic data icin

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

A = EEG.icawinv;

% neglect the FID electrodes
y = elp_index;
N = length(y);
for i = 1:N
    elocn(i).labels = eloc(y(i)).labels;
    elocn(i).X = eloc(y(i)).X;
    elocn(i).Y = eloc(y(i)).Y;
    elocn(i).Z = eloc(y(i)).Z;
 %   elocn(i).type = eloc(y(i)).type;
end

Nel2 = length(elocn);
Neeg = length(EEG.chanlocs);

Mel2 = zeros(1, Nel2);
Meeg = zeros(1, Neeg);

% Mel2(i) = index of EEG.chanlocs that correspond to electrode i of eloc2
% Meeg(i) = index of elocn that correspond to electrode i of EEG.chanlocs
clear Mel2 Meeg
for i = 1:Nel2
    for j = 1:Neeg
        if strcmp(elocn(i).labels, EEG.chanlocs(j).labels)
            Mel2(i) = j;
            Meeg(j) = i;
            continue;
        end
    end
end

ind_fp = find(Mel2>0); % index for the FP outputs (LFM, TM, session)
ind_eeg = find(Meeg>0); % index for the EEG structure (ICs)
