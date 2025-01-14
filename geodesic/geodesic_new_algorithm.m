function algorithm = geodesic_new_algorithm(mesh, type, subdivision)

if nargin == 2
    subdivision = 0;
end

if strcmp(type, 'subdivision') & subdivision == 0
    type = 'dijkstra';
end;

algorithm_types = {'exact', 'subdivision', 'dijkstra'};
type_id = find(strcmp(type, algorithm_types));
if isempty(type_id)
    disp('error: algorithm type is incorrect');
    return;
end
type_id = type_id - 1;

algorithm.id = geodesic('new_algorithm', mesh.id, type_id, subdivision);
algorithm.type = type;
algorithm.object_type = 'algorithm';
