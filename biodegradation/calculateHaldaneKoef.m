function calculateHaldaneKoef()

data = loadData();
testsSize = length(data);
OUTPUT_MODE = false;
if OUTPUT_MODE == true
    load data data;
end
for testNum = 1:testsSize
    if OUTPUT_MODE == true
        break;
    end
    X = data{testNum}.X;
    T = data{testNum}.T;
    C = data{testNum}.C;
    v = data{testNum}.v;
    ssv = mean(X);
    C0 = C(1);

    funK = @(k) C_runge(k, T, C0, ssv, v, false);
    lb(1:3) = 1e-10;
    ub(1:3) = max(C);
    A=[]; b = [];
    kFirst = fitParameters(funK, C, lb, ub, A, b);
    data{testNum}.kFirst=kFirst;
    disp(kFirst);
    
    frequency = 455;
    T_ext = linspace(0, max(T), frequency);
    C_ext = C_runge(kFirst, T_ext, C0, ssv, v, false);
    R = -diff(C_ext(1:2:end))./diff(T_ext(1:2:end));
    T = T_ext(2:2:end);
    C = C_ext(2:2:end);
    R_exp = R ./ max(R);
    kSecond = fitParameters(@(k)R_cal(k, C), R_exp, lb(1:2), ub(1:2), A, b);
    data{testNum}.R_exp = R_exp;
    data{testNum}.C_exp = C;
    disp(kSecond);
    
    funK = @(k)C_runge(k, T, C0, ssv, v, false, kSecond(1), kSecond(2));
    kMax = fitParameters(funK, C, lb(1), ub(1), [], []);
    data{testNum}.kSecond = [kMax kSecond];
    disp(kMax);
end
if OUTPUT_MODE == false
    save data data;
end
plotData(data);
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function plotData(data)
    figure();
    testsSize = length(data);
    for testNum = 1:testsSize
        for i = 1:3
            X = data{testNum}.X;
            T = data{testNum}.T;
            C = data{testNum}.C;
            v = data{testNum}.v;
            ssv = mean(X);
            C0 = C(1);
            
            if i == 1
                k = data{testNum}.kFirst;
            else
                k = data{testNum}.kSecond;
            end
            
            subplot(testsSize, 3, (testNum - 1) * 3 + i);   
            if i == 2
                fplot(@(C)R_cal(k(2:3), C), [0  1.1*max(C)]);
                hold on;
                plot(C, R_cal(k(2:3), C), 'bo', 'LineWidth', 2);
                axis([0,inf,0,inf]);
                xlabel('C');
                ylabel('R');
                plot(data{testNum}.C_exp, data{testNum}.R_exp, 'rx', 'LineWidth', 2);
                 title(['[' data{testNum}.title '] K_s=' num2str(k(2)) ' K_I=' num2str(k(3))]);
            else
                funK = @(T)C_runge(k, T, C0, ssv, v, true);
                hold on;
                C_interp = @(t)interp1(T, funK(T), t, 'linear');
                fplot(@(t)C_interp(t), [0  max(T)]);
                plot(T, funK(T), 'bo', 'LineWidth', 2);
                axis([0,inf,0,inf]);
                xlabel('t');
                ylabel('C');
                title(['[' data{testNum}.title '] K_{max}=' num2str(k(1)) ' K_s=' num2str(k(2)) ' K_I=' num2str(k(3))]);
                plot(T, C, 'rx', 'LineWidth', 2);
            end
            
        end
    end
end

function k = fitParameters(funK, funExp, lb, ub, A, b)
    nvars = length(lb);
    x0 = (ub - lb)./2;
    optionsGA = gaoptimset('PopInitRange',  [min(lb); max(ub)], 'Display', 'iter');
    optionsGA.PopulationSize = 100;
    optionsGA.Generations = 30;
    funGoal =  @(k)sum((funK(k) - funExp).^2);
    [x0 errfun] = ga(funGoal, nvars, A, b, [], [], lb, ub, [], [], optionsGA);
    Cproblem = createOptimProblem('fmincon', 'x0', x0,'objective', funGoal,...
        'Aineq', A, 'bineq', b, 'lb', lb,'ub', ub);
    [k, errormulti] = run(GlobalSearch,Cproblem);
end

%k - var;
function y = C_runge(k, T, C0, ssv, v, isExact, k2, k3)
    if(nargin <= 6)
        k2 = [];
        k3 = [];
    end
    if (~isExact)
        %Euler method
        size=length(T);
        y=zeros(1,size);
        for i=1:size
            if(i == 1)
                y(1)=C0;
            else
                y(i) = y(i-1) + F(0, y(i-1), k2, k3) * (T(i)-T(i-1));
            end
        end
    else
        %Runge Kutta
        options = odeset('RelTol',1e-4, 'AbsTol', 1e-4);
        [~,y] = ode23t(@(T, C)F(T, C, k2, k3), T, C0, options);
        y=y';
    end

function dCdt = F(t, c, k2, k3)
    if(isempty(k2) && isempty(k3))
        dCdt = -k(1)*ssv*c/(v*(c+k(2)+c.^2/k(3)));
    else
        dCdt = -k(1)*ssv*c/(v*(c+k2+c.^2/k3));
    end
end
end

function y = C_trap(k, T, C, ssv, v)
    size=length(T);
    y=zeros(1,size);
    for i=1:size
        if(i == 1)
            y(1)=C(1);
        else
            y(i)= y(i-1)+(F(k, i)+F(k, i-1))./2 .* (T(i)-T(i-1));
        end
    end
        function y = F(k, i)
            y = -k(1)*ssv*C(i)/(v*(C(i)+k(2)+C(i).^2/k(3)));
        end
end

function y = R_cal(k, C)
y = C.*(1+2*sqrt(k(1)/k(2)))./(k(1)+C+C.^2/k(2));
end










