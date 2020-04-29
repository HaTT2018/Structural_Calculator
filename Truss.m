clear;clc;hold off;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% below is the overall structure
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if_internal = 1;
nodes = [
    0 0;
    12 0;
    12 16;
    12 25;
    0 34;
    -12 34;
    -24 34;
    -12 25;
    0 25;
    0 16
    ]; % input nodes here, first column of matrix 'nodes' is x cord, second colomn is y

elements = [1 2;
            2 3;
            3 4;
            4 5;
            5 6;
            6 7;
            7 8;
            8 9;
            9 10;
            10 1;
            2 10;
            3 10;
            4 10;
            4 9;
            5 9;
            5 8;
            6 8
            ]'; % each ![row]! represents an element, from node a to node b

SupportTypesOnNodes = [1;2;0;0;0;0;0;0;0;0]; % a vector that indicates how many unknown forces on each node respectively

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% External loads
ExF = [
       -12, 0, 0, 34;
       0, -30, -24, 34;
       0, -18, -12, 25
       ]; % each row: [Fx,Fy,x,y]

ExM = [0, 0, 0]; % [mag, x, y]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if size(elements,2)*3 < sum(SupportTypesOnNodes)
    disp('Structure indeterminante!')
    return
end

%% Calculate reaction forces
F_sol = zeros(sum(SupportTypesOnNodes),1);

    
% create unknown variables of reaction forces on each nodes
syms F_react [length(SupportTypesOnNodes) 3] % each row cooresponds a node

% release free degrees
for j=1:length(SupportTypesOnNodes)
    if SupportTypesOnNodes(j)==1
        F_react(j,1)=0;
        F_react(j,3)=0;
    elseif SupportTypesOnNodes(j)==2
        F_react(j,3)=0;
    elseif SupportTypesOnNodes(j)==0
        F_react(j,1)=0;
        F_react(j,2)=0;
        F_react(j,3)=0;
    end
end
    
    
Fx = sum(F_react(:,1)) + sum(ExF(:,1));
Fy = sum(F_react(:,2)) + sum(ExF(:,2));

Mo = sum(ExM(:, 1), 1);
for i=size(ExF, 1)
    Mo = cross([ExF(i, 3:4) 0], [ExF(i, 1:2) 0]);
end

for k=1:size(F_react,1)
    Mo = Mo + cross([nodes(k,:) 0], [F_react(k,1:2) 0]);
end

EqnSet = [ Fx == 0; Fy == 0; Mo(3) == 0];

% sol = struct2cell(solve([ Fx == 0; Fy == 0; Mo(3) == 0]));
% F_sol = F_sol + double(cat(1,sol{:}));


%% calculate internal forces
syms F_internal [size(nodes, 1), size(nodes, 1)] 

ele_mat = zeros(size(nodes, 1), size(nodes, 1));
for i=1:size(elements, 2)
    ele_mat(elements(1,i), elements(2,i)) = 1;
end

% #internal forces equals # elements, from node c(column) to node r (row)
F_internal = F_internal.*ele_mat;

total_F = [ExF; F_react(:, 1:2), nodes];

EqnSet_int = [];
for i=1:size(nodes,1)
    node_x = nodes(i,1);
    node_y = nodes(i,2);
    
    % find the external forces (include reaction forces) that exert on 
    % this node, return the index of node(s)
    ExF_ind = find(abs(total_F(:,3)-node_x)<1e-10 & abs(total_F(:,4)-node_y)<1e-10);
            
    ExF_t = total_F(ExF_ind, :);
    ExF_t = sum(ExF_t(:, 1:2), 1);
    
    % find the elements on this node (OTN), return the column index of matrix 
    % "elements"
    out = find(elements(1, :)==i);
    out = [out; ones(1, length(out))];
    elements_ONT_out = [elements(:, out(1, :)); ones(1, size(out, 2))]; % the third row=1 means it points out
    
    in = find(elements(2, :)==i);
    in = [in; -ones(1, length(in))];
    elements_ONT_in = [elements(:, in(1, :)); -ones(1, size(in, 2))]; % the third row=-1 means it points in
    
    elements_ONT = [elements_ONT_out, elements_ONT_in]; % each column: from node, to node
    
    % F_internal_ONT: each row: Fx, Fy
    syms F_internal_ONT [0,0]
    for j = 1:size(elements_ONT, 2)
        F_internal_ONT(j, :) = elements_ONT(3,j) * ... % mean out/in
                                (nodes(elements_ONT(2,j), :) - nodes(elements_ONT(1,j), :))... % direction
                                /norm((nodes(elements_ONT(2,j), :) - nodes(elements_ONT(1,j), :))) * ... % normalization
                                F_internal(elements_ONT(1,j), elements_ONT(2,j));
    end
        
    % Fx = 0, Fy = 0
    newEqn = sum(F_internal_ONT, 1)+ExF_t==[0,0];
    EqnSet_int = [EqnSet_int; newEqn(:)];
end

if if_internal == 1
    EqnSet = [EqnSet; EqnSet_int];
end
   
try
    s = solve(EqnSet);
    F_name = fieldnames(s);
    sol = struct2cell(s);
    sol = double(cat(1,sol{:}));
    sol(1)==sol(1)
catch
    s = solve(EqnSet_int);
    F_name = fieldnames(s);
    sol = struct2cell(s);
    sol = double(cat(1,sol{:}));
end
    



%% display forces in command line
for i=1:size(sol,1)
    if sol(i)>0
        TorC = 'Tension';
    elseif sol(i)<0
        TorC = 'Compression';
    else
        TorC = 'zero';
    end

    disp([F_name{i}, string(sol(i)), TorC]);
end


%% fill solution into force matrices (internal and reaction)
NumOfIntF = 0;
if if_internal == 1
    NumOfIntF = length(F_internal(F_internal~=0)); % number of internal forces
    F_internal_res = zeros(size(F_internal'));
    for i=1:NumOfIntF
        F_name_this = F_name{i};
        a_ind = strfind(F_name_this, 'l'); % index of 'l'
        b_ind = strfind(F_name_this, '_'); % index of '_'
        b_ind = b_ind(2);
        from = str2double(F_name_this(a_ind+1:b_ind-1));
        to = str2double(F_name_this(b_ind+1:length(F_name_this)));
        F_internal_res(from, to) = sol(i);
    end
    
end
F_react_f = F_react(:, 1:2);% matrix of reaction forces
NumOfReactF = length(F_react_f(F_react_f~=0));% number of reaction forces


F_react_f_res = zeros(size(F_react_f));
for i=1:NumOfReactF
    F_name_this = F_name{i+NumOfIntF};
    a_ind = strfind(F_name_this, 't'); % index of 't'
    b_ind = strfind(F_name_this, '_'); % index of '_'
    b_ind = b_ind(2);
    from = str2double(F_name_this(a_ind+1:b_ind-1));
    to = str2double(F_name_this(b_ind+1:length(F_name_this)));
    F_react_f_res(from, to) = sol(i+NumOfIntF);
end



%% draw force illustration
F_react = [F_react_f_res, nodes];
total_F = [ExF; F_react];

gen_fig(nodes, elements, SupportTypesOnNodes, F_internal_res)
draw_loads(total_F, ExM)







%% functions
function gen_fig(nodes, elements, SupportTypesOnNodes, F_internal_res)
    hold on
    xlim([-2+min(nodes(:,1)), 2 + max(nodes(:,1))])
    ylim([-2 + min(nodes(:,2)), 2 + max(nodes(:,2))])
    grid on

    max_mag = max(F_internal_res(:));
    for i=1:size(elements, 2)
        from = elements(1, i);
        to = elements(2, i);
        lw = 10*abs(F_internal_res(from, to)/max_mag); % linewidth
        if F_internal_res(from, to) > 0
            plot( nodes(elements(:, i), 1), nodes(elements(:, i), 2), 'color', 'blue', 'LineWidth', lw) % plot, tension
        elseif F_internal_res(from, to) < 0
            plot( nodes(elements(:, i), 1), nodes(elements(:, i), 2), 'color', 'red', 'LineWidth', lw) % plot, tension
        else
            plot( nodes(elements(:, i), 1), nodes(elements(:, i), 2), 'color', 'green') % plot, tension
        end
    end
    
    for i=1:size(nodes, 1)
        if SupportTypesOnNodes(i)==2
            plot(nodes(i,1), nodes(i,2), 'Marker', '^', 'MarkerFaceColor', 'black', 'MarkerSize', 10)
        elseif SupportTypesOnNodes(i)==1
            plot(nodes(i,1), nodes(i,2), 'Marker', 'o', 'MarkerFaceColor', 'black', 'MarkerSize', 10)
        end
    end
end

function draw_loads(total_F, ExM)
    M_mag = abs(ExM(:,1));
    if sum(M_mag) > 1e-5
        max_M = max(M_mag);
        for i=size(ExM,1)
            if ExM(i,1)<=0
                plot(ExM(i,2),ExM(i,3), 'Marker', 'x', 'Color', 'g', 'MarkerSize', 20*M_mag(i)/max_M, 'LineWidth', 4*M_mag(i)/max_M)
            elseif ExM(i,1)>0
                plot(ExM(i,2),ExM(i,3), 'Marker', 'o', 'Color', 'r', 'MarkerSize', 20*M_mag(i)/max_M, 'LineWidth', 4*M_mag(i)/max_M)
            end
        end
    end
    
    F_mag = sqrt(sum((total_F(:,1:2).^2)')');
    if sum(F_mag) > 1e-5
        max_F = max(F_mag)*0.8;
        for i=1:size(total_F, 1)
            if total_F(i,1)==0&&total_F(i,2)==0
                continue
            end
            Mo = cross([total_F(i, 3:4) 0], [total_F(i, 1:2) 0]);
            
            if Mo(3)<0
                plot(linspace(min(total_F(i,3), total_F(i,3) - total_F(i,1)/max_F),...
                    max(total_F(i,3), total_F(i,3) - total_F(i,1)/max_F),50),...
                    linspace(min(total_F(i,4), total_F(i,4)-total_F(i,2)/max_F),...
                    max(total_F(i,4), total_F(i,4)-total_F(i,2)/max_F),50), 'g.')
                plot(total_F(i,3), total_F(i,4), 'Marker', 'd', 'Color', 'g', 'MarkerSize', 7, 'MarkerFaceColor', 'green')
            elseif Mo(3)>0
                plot(linspace(min(total_F(i,3), total_F(i,3) - total_F(i,1)/max_F),...
                    max(total_F(i,3), total_F(i,3) - total_F(i,1)/max_F),50),...
                    linspace(min(total_F(i,4), total_F(i,4)-total_F(i,2)/max_F),...
                    max(total_F(i,4), total_F(i,4)-total_F(i,2)/max_F),50), 'r.')
                plot(total_F(i,3), total_F(i,4), 'Marker', 'd', 'Color', 'r', 'MarkerSize', 7, 'MarkerFaceColor', 'red')
            else
                plot(linspace(min(total_F(i,3), total_F(i,3) - total_F(i,1)/max_F),...
                    max(total_F(i,3), total_F(i,3) - total_F(i,1)/max_F),50),...
                    linspace(min(total_F(i,4), total_F(i,4)-total_F(i,2)/max_F),...
                    max(total_F(i,4), total_F(i,4)-total_F(i,2)/max_F),50), 'black.')
                plot(total_F(i,3), total_F(i,4), 'Marker', 'd', 'Color', 'white', 'MarkerSize', 7, 'MarkerFaceColor', 'black')
            end
        end
    end
    
end








