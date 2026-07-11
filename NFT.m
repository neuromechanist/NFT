% NFT() - Short alias that opens the Neuroelectromagnetic Forward Modeling
%         Toolbox (NFT) main GUI. All arguments are forwarded verbatim to
%         Neuroelectromagnetic_Forward_Modeling_Toolbox().
%
% Usage:
%   >> NFT;                 % open the NFT main window
%   >> varargout = NFT(varargin);
%
% See also: Neuroelectromagnetic_Forward_Modeling_Toolbox

function varargout = NFT(varargin)

if nargout
    [varargout{1:nargout}] = Neuroelectromagnetic_Forward_Modeling_Toolbox(varargin{1:nargin});
else
    Neuroelectromagnetic_Forward_Modeling_Toolbox(varargin{1:nargin});
end
