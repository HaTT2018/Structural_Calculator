clear; clc; close all;
% unit: N, m

nodes = [0 0;
        0 0.2;
        0.4 0.2;
        0.4 0];

eles = [1 2;
       2 3;
       3 4
       ];

% Geometry properties
E = 2e11 * ones(3, 1);
A = 5624*1e-6*ones(3, 1);
I = 61200000*1e-12 * ones(3, 1);

L = [];
for i = 1:size(eles, 1)
    start_node = eles(i, 1);
    end_node = eles(i, 2);
    vec = nodes(end_node, :) - nodes(start_node, :);
    L(i) = norm(vec);
end


% 3 means xyz constrained, 2 means xy constrained
% 13 means z constrained, 12 means y constrained, 11 means x constrained,
% hinge not contained
Supporting = [2 0 0 2]';

% released nodes, n by 1
nodes_r = [3]';

% nodal forces (global), [Fx, Fy, node#]
ExF = []; 

% equivalant external element element end forces (LOCAL)
% [fyi, mi, fyj, mj, ele#]
w1 = 20e3; 
p2 = 20e3; a = 0.3; b = 0.1;
ExEF = [-7*w1*L(1)/20, -w1*L(1)^2/20, -3*w1*L(1)/20, w1*L(1)^2/30, 1;
        -p2*b^2*(L(2)+2*a)/L(2)^3, -p2*a*b^2/L(2)^2, -p2*a^2*(L(2)+2*b)/L(2)^3, p2*b*a^2/L(2)^2, 2];

% element freedom table, each node has 3 DoFs
EFT = 1:1:3*size(nodes, 1);

%% Construct K_ff
K = zeros(size(EFT, 2));

for i = 1:size(eles, 1)
    start_node = eles(i, 1);
    end_node = eles(i, 2);
    vec = nodes(end_node, :) - nodes(start_node, :);
    th = atan(vec(2)/vec(1));
    if vec(1) < 0
        th = th + pi;
    end
    c = cos(th);
    s = sin(th);
    
    % transformation matrix
    T_e = [c s 0 0 0 0;
           -s c 0 0 0 0;
           0 0 1 0 0 0;
           0 0 0 c s 0;
           0 0 0 -s c 0;
           0 0 0 0 0 1];
       
    A_i = A(i);
    L_i = L(i);
    E_i = E(i);
    I_i = I(i);
    % local stifness matrix for element i
    k_e_b = [A_i*E_i/L_i    0                   0                   -A_i*E_i/L_i    0                   0;
             0              12*E_i*I_i/L_i^3    6*E_i*I_i/L_i^2     0               -12*E_i*I_i/L_i^3   6*E_i*I_i/L_i^2;
             0              6*E_i*I_i/L_i^2     4*E_i*I_i/L_i       0               -6*E_i*I_i/L_i^2    2*E_i*I_i/L_i;
             -A_i*E_i/L_i   0                   0                   A_i*E_i/L_i     0                   0;
             0              -12*E_i*I_i/L_i^3   -6*E_i*I_i/L_i^2    0               12*E_i*I_i/L_i^3    -6*E_i*I_i/L_i^2;
             0              6*E_i*I_i/L_i^2     2*E_i*I_i/L_i       0               -6*E_i*I_i/L_i^2    4*E_i*I_i/L_i;
            ];
    
    % global stifness matrix for element i
    k_e = T_e'*k_e_b*T_e;
    
    % element free table for element i
    EFTe = [EFT(3*start_node - 2:3*start_node), EFT(3*end_node - 2:3*end_node)];
    
    % modify the global stifness matrix
    K(EFTe, EFTe) = K(EFTe, EFTe) + k_e;
end

EFTf = [];
for i = 1:size(Supporting, 1)
    if Supporting(i, 1) == 11
        EFTf = [EFTf EFT(3*i-1) EFT(3*i)];
    elseif Supporting(i, 1) == 12
        EFTf = [EFTf EFT(3*i-2) EFT(3*i)];
    elseif Supporting(i, 1) == 13
        EFTf = [EFTf EFT(3*i-2) EFT(3*i-1)];
    elseif Supporting(i, 1) == 2
        EFTf = [EFTf EFT(3*i)];
    elseif Supporting(i, 1) == 0
        EFTf = [EFTf EFT(3*i-2:3*i)];
    end
end

Kff = K(EFTf, EFTf);

%% Construct f_ff (contained moments)
f = zeros(size(EFT, 2), 1);
for i = 1:size(ExF, 1)
    f_EFT = [3*ExF(i, 3)-2, 3*ExF(i, 3)-1];
    f(f_EFT) = f(f_EFT) + ExF(i, 1:2)';
end

for i = 1:size(ExEF, 1)
    ele = ExEF(i, 5);
    start_node = eles(ele, 1);
    end_node = eles(ele, 2);
    vec = nodes(end_node, :) - nodes(start_node, :);
    th = atan(vec(2)/vec(1));
    if vec(1) < 0
        th = th + pi;
    end
    c = cos(th);
    s = sin(th);
    L_e = L(ele);
    
    % transformation matrix
    T_e = [c s 0 0 0 0;
           -s c 0 0 0 0;
           0 0 1 0 0 0;
           0 0 0 c s 0;
           0 0 0 -s c 0;
           0 0 0 0 0 1];
    % local equivalant force
    f_EF_i_b = [0 ExEF(i, 1:2) 0 ExEF(i, 3:4)]';
    
    % global equivalant force
    f_EF_i = T_e'*f_EF_i_b;
    
    f_EFT = [(3*start_node-2:3*start_node) (3*end_node-2:3*end_node)];
    
    f(f_EFT) = f(f_EFT) + f_EF_i;
end

f_ff = f(EFTf);

%% Caculate displacement for free degrees
u_ff = Kff^-1*f_ff;
u = zeros(size(EFT, 2), 1);
u(EFTf) = u_ff;
disp('u(m)=');
disp(u);

%% Calculate element end forces
f_ele_end = zeros(6, size(eles, 1));


for i = 1:size(eles, 1)
    start_node = eles(i, 1);
    end_node = eles(i, 2);
    vec = nodes(end_node, :) - nodes(start_node, :);
    th = atan(vec(2)/vec(1));
    if vec(1) < 0
        th = th + pi;
    end
    c = cos(th);
    s = sin(th);
    
    % transformation matrix
    T_e = [c s 0 0 0 0;
           -s c 0 0 0 0;
           0 0 1 0 0 0;
           0 0 0 c s 0;
           0 0 0 -s c 0;
           0 0 0 0 0 1];
       
    A_i = A(i);
    L_i = L(i);
    E_i = E(i);
    I_i = I(i);
    % local stifness matrix for element i
    k_e_b = [A_i*E_i/L_i    0                   0                   -A_i*E_i/L_i    0                   0;
             0              12*E_i*I_i/L_i^3    6*E_i*I_i/L_i^2     0               -12*E_i*I_i/L_i^3   6*E_i*I_i/L_i^2;
             0              6*E_i*I_i/L_i^2     4*E_i*I_i/L_i       0               -6*E_i*I_i/L_i^2    2*E_i*I_i/L_i;
             -A_i*E_i/L_i   0                   0                   A_i*E_i/L_i     0                   0;
             0              -12*E_i*I_i/L_i^3   -6*E_i*I_i/L_i^2    0               12*E_i*I_i/L_i^3    -6*E_i*I_i/L_i^2;
             0              6*E_i*I_i/L_i^2     2*E_i*I_i/L_i       0               -6*E_i*I_i/L_i^2    4*E_i*I_i/L_i;
            ];
    
    % global stifness matrix for element i
    k_e = T_e'*k_e_b*T_e;
    
    % element free table for element i
    EFTe = [EFT(3*start_node - 2:3*start_node), EFT(3*end_node - 2:3*end_node)];
    
    % f = k_e*u_e - f_EF_e
    if ismember(i, ExEF(:, 5)) == 0
        f_EF_e = zeros(6, 1);
    else
        f_EF_e_b = ExEF(ismember(ExEF(:, 5), i), :);
        f_EF_e_b = [0 f_EF_e_b(1:2) 0 f_EF_e_b(3:4)]';
        f_EF_e = T_e' * f_EF_e_b;
    end
    u_e = u(EFTe);
    f = k_e * u_e - f_EF_e;
    
    f_ele_end(:, i) = f;
end

disp('Element end forces(N)=');
disp(f_ele_end);

%% Calculate reactions
support_nodes = find(Supporting~=0);
reactions = zeros(3 * size(support_nodes, 1), 1);
for i = 1 : size(support_nodes, 1)
    % find which element this support node is
    e = find(eles == support_nodes(i));
    e_ind = ceil(e/2);
    n_ind = 2 - ceil(e_ind - e/2);
    
    % reaction = f_ele_end
    reactions(3*i-2:3*i) = f_ele_end(3*n_ind-2:3*n_ind, e_ind);
    if Supporting(support_nodes(i)) == 2
        reactions(3*i) = NaN;
    elseif Supporting(support_nodes(i)) == 11
        reactions(3*i-1) = NaN;
        reactions(3*i) = NaN;
    elseif Supporting(support_nodes(i)) == 12
        reactions(3*i-2) = NaN;
        reactions(3*i) = NaN;
    elseif Supporting(support_nodes(i)) == 13
        reactions(3*i-2) = NaN;
        reactions(3*i-1) = NaN;
    end
end
disp('Supporting nodes are')
disp(support_nodes)
disp('Reactions(N)=')
disp(reactions)































