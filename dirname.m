function name = dirname(path)
% name = dirname(path)
% 
% This is an attempt to recreate the unix dirname command
% in matlab.
%


%
% dirname.m
%
% Original Author: Doug Greve
% CVS Revision Info:
%    $Author: nicks $
%    $Date: 2007/01/10 22:02:29 $
%    $Revision: 1.3 $
%
% Copyright (C) 2002-2007,
% The General Hospital Corporation (Boston, MA). 
% All rights reserved.
%
% Distribution, usage and copying of this software is covered under the
% terms found in the License Agreement file named 'COPYING' found in the
% FreeSurfer source code root directory, and duplicated here:
% https://surfer.nmr.mgh.harvard.edu/fswiki/FreeSurferOpenSourceLicense
%
% General inquiries: freesurfer@nmr.mgh.harvard.edu
% Bug reports: analysis-bugs@nmr.mgh.harvard.edu
%

if(nargin ~= 1)
  msg = 'USAGE: name = dirname(path)'
  qoe(msg); error(msg);
end

len = length(path);

% Find all the forward slashes
ind = findstr('/',path);

if(isempty(ind)) 
  % No forward slashes
  name = '.';
  return; 
end

% Substitute blank for all forward slashs
tmp = path;
tmp(ind) = ' ';

% Split the string by blanks
tmp2 = splitstring(tmp);

if(size(tmp2,1) == 1) 
  % Only one string remains, could be one of three:
  % (1) Leading slash
  % (2) Trailing slash
  % (3) Both Leading and Trailing slashs
  if(path(1) == '/' )        name = '/'; % Handles 1 and 3
  else 
    if(path(len) == '/' ) name = '.'; end % Handles 2
  end
  return;
end

if(size(tmp2,1) == 2) 
  % Only two strings, directory name must be the first
  name = deblank(tmp2(1,:));
else
  % Multple strings remain. Concat all but the last together
  name = deblank(tmp2(1,:));
  for n = 2:size(tmp2,1)-1
    name = sprintf('%s/%s',name,deblank(tmp2(n,:)));
  end
end

if(path(1) == '/')  name = sprintf('/%s',name); end

return

%%%% Below is the old method %%%%

len = length(path);

% Strip out duplicate forward slashes
m=1;
for n=1:len
  if(n ~= len & path(n) == '/' & path(n+1) == '/') continue; end
  tmppath(m) = path(n);
  m = m+1;
end

path = tmppath;
len = length(path);

% If there is only one character in the path  %
if(len == 1) 
  if(strcmp(path,'/'))
    name = '/';
  else
    name = '.';
  end
  return;
end

for n = len-1:-1:1
  if(strcmp(path(n),'/'))
    name = path(1:n);    
    return;
  end
end

name = '.';

return;
