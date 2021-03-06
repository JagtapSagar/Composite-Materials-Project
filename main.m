clear; clc;
%%
% Following values have to be entered;
% Axial Modulus E1 (Pa)
% Transverse Modulus E2 (Pa)
% Poisson’s Ratio ν12 (non-dimmensional)
% Shear Modulus G12 (Pa)
% Axial CTE α1 or a1(μ/°C)
% Transverse CTE α2 or a2(μ/°C)
% Longitudinal Tensile Strength XT (Pa)
% Longitudinal Compressive Strength XC (Pa)
% Transverse Tensile Strength YT (Pa)
% Transverse Compressive Strength YC (Pa)
% In-Plane Shear Strength S (Pa)
% Lamina orientation vector thetas (degrees)
% Forces (N/m) [Nx Ny Nxy]
% Moments (N) [Mx My Mxy]
% Temperature change ΔT or dT (°C)
% ΔC or dC


% Values to be entered here. Following values were used for testing purposes
E1 = 38.6e9; E2 = 8.27e9; G12 = 4.14e9;
v12 = 0.26;
a1 = 8.6e-6; a2 = 22.1e-6;
Xt = 1062e6; Xc = -610e6; Yt = 31e6; Yc = -118e6; S = 72e6;
dT = -200; dC = 0;
thetas_1 = [0 45 -45 90 90 -45 45 0];
thetas_2 = [45 0 -45 90 90 -45 0 45];
thetas_3 = [45 -45 0 90 90 0 -45 45];
thetas_4 = [45 -45 90 0 0 90 -45 45];
thetas = thetas_1;

%% Main program
% Calculating Strength tensors
F1 = 1/Xt+1/Xc; F2 = 1/Yt+1/Yc;                             % Unit: 1/Pa
F11 = -1/(Xt*Xc); F22 = -1/(Yt*Yc); F66 = 1/S^2;            % Unit: 1/Pa^2

num = length(thetas_1);   % Number of layers
flag = 0;
fprintf('\n =======================================================')
fprintf('\n               NO. OF          LAMINA          SR (MIN) ')
fprintf('\n  LAYER      ITERATIONS       THICKNESS         VALUE ')
fprintf('\n =======================================================')
for k=1:num
    t = 1.0e-3;       % Initial thickness value. Unit: m
    it_count = 0;    % iteration count
    %SR_mat = zeros(50,1);
    %t_mat = zeros(50,1);
    while (flag<1)
        it_count = it_count + 1;
        H = t*num/2;
        
        % Calculate ADB, Force matrices
        [ABD, Force] = ABDmatrix_Forcematrix(thetas, H, t, E1, E2, v12, G12,a1, a2, dT);
        % Calclate Qbar matrix for stress calculations at top, middle and
        % bottom of each layer
        [Qbar,~] = Qbar_Sbar(E1,E2,v12,G12,thetas(k));
        z_top = -H + (k-1)*t;
        z_mid = -H + (k-0.5)*t;
        z_bot = -H + k*t;
        Epsilon_Kappa = inv(ABD)*Force;
        [Epsilon_Th] = Epsilon_Thermal(thetas(k),dT,a1,a2); % Unitless
        Epsilon_Mech_top = Epsilon_Kappa(1:3,1) + z_top*Epsilon_Kappa(4:6,1) - Epsilon_Th; % Unitless
        Epsilon_Mech_mid = Epsilon_Kappa(1:3,1) + z_mid*Epsilon_Kappa(4:6,1) - Epsilon_Th; % Unitless
        Epsilon_Mech_bot = Epsilon_Kappa(1:3,1) + z_bot*Epsilon_Kappa(4:6,1) - Epsilon_Th; % Unitless
        
        % Stresses for top, mid and bot
        [T1,T2] = T1_T2(thetas(k));
        sigma_gt = Qbar*Epsilon_Mech_top;
        sigma_1t = T1*sigma_gt;
        sigma_gm = Qbar*Epsilon_Mech_mid;
        sigma_1m = T1*sigma_gm;
        sigma_gb = Qbar*Epsilon_Mech_bot;
        sigma_1b = T1*sigma_gb;
        s1_top = sigma_1t(1); s2_top = sigma_1t(2); s12_top = sigma_1t(3);
        s1_mid = sigma_1m(1); s2_mid = sigma_1m(2); s12_mid = sigma_1m(3);
        s1_bot = sigma_1b(1); s2_bot = sigma_1b(2); s12_bot = sigma_1b(3);
        
        % TsaiWu Failure Criterion
        % Least of tollowing has to be >=1
        %TsaiWu_top = F1*s1_top + F2*s2_top + F11*s1_top^2 + F22*s2_top^2 + F66*s12_top^2;
        %TsaiWu_mid = F1*s1_mid + F2*s2_mid + F11*s1_mid^2 + F22*s2_mid^2 + F66*s12_mid^2;
        %TsaiWu_bot = F1*s1_bot + F2*s2_bot + F11*s1_bot^2 + F22*s2_bot^2 + F66*s12_bot^2;
        
        % Equations for TsaiWu
        syms SRt SRm SRb;
        Eqn_t = SRt*(F1*s1_top + F2*s2_top) + SRt^2*(F11*s1_top^2 + F22*s2_top^2 + F66*s12_top^2)-1;
        Eqn_m = SRm*(F1*s1_mid + F2*s2_mid) + SRm^2*(F11*s1_mid^2 + F22*s2_mid^2 + F66*s12_mid^2)-1;
        Eqn_b = SRb*(F1*s1_bot + F2*s2_bot) + SRb^2*(F11*s1_bot^2 + F22*s2_bot^2 + F66*s12_bot^2)-1;
        
        % Solving for SR values
        solt = double(solve(Eqn_t));    % top
        SR_top = solt(solt>0);
        solm = double(solve(Eqn_m));    % mid
        SR_mid = solm(solm>0);
        solb = double(solve(Eqn_b));    % bot
        SR_bot = solb(solb>0);
        
        % Taking the least of the Strength Ratio's
        SR = min([SR_top,SR_mid,SR_bot]);
        
        % Update thickness to optimize SR (ideal SR 1 +/- 0.01)
        if SR>1.01
            t = t - t/10;
        elseif SR<0.99
            t = t + t/10;
        else
            break;
        end
    end
    
    %% if optimum thickness is found
    if (0.99<SR && SR<1.01)
        fprintf('\n    %i \t\t\t %2i   \t\t    %.3f   \t    %.3f',k,it_count,t*1000,SR)
    end
end

fprintf('\n');
