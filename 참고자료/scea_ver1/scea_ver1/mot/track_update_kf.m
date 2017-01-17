function [Track] = track_update_kf(Track, frame, opt, param, f)


for i = 1:length(Track)
    Gp_x = Track{i}.graph_x; % predicted states from self motion and relational function
    P = Track{i}.Pp; % predicted covariance
    s_asso = Track{i}.asso_spatial;
    Det = Track{i}.detection;
    graph_weight = Track{i}.graph_weight;
    states = Track{i}.states;
    size_states = size(states,2);
    if(~isempty(Det) && max(s_asso)>=opt.PASCAL_Th) % Update with observations (Smoothness)
%         Det = [Det(1:2)+Det(3:4)/2;Det(3:4)]; % [Cen X, Y, W, H]
        
        % check pascal score
        %                 idx = find(s_asso <= 0.1);
        %                 Gp_x(:,idx) = []; s_asso(idx) = [];
        
        graph_weight(1,:) = graph_weight(1,:).*s_asso';
        graph_weight(1,:) = graph_weight(1,:)/sum(graph_weight(1,:));
        Track{i}.graph_weight = graph_weight;
        
        % select the most reliable node or neighbor
        [max_val, max_idx] = max(s_asso);
        x_max = Gp_x(:,max_idx); %% �ٽ� �˻�
        %                 x_max = Track{i}.Xp;
        cov_dist = diag(Det(3:4)/2 + x_max(5:6)/2).^2;
        R = [cov_dist, zeros(2,2);zeros(2,2), param.R(3:4,3:4)];
        S = param.H*P*param.H' + R;
        K = P*param.H'*inv(S);
        x = x_max + K*(Det - param.H*x_max);
        P = P - K*S*K';
        
        
        
        W = mean([states(3,end) Det(3)]);
        H = mean([states(4,end) Det(4)]);
        
%         W = 0.3*states(3,end) + 0.7*Det(3);
%         H = 0.3*states(4,end) + 0.7*Det(4);
        
        Track{i}.X = [Det(1:2); x(3:4);W;H];
        Track{i}.P = P;
        
%         xstate = [x(1:2); x(5); x(6); x(3:4)]; % [center u, v, w, h, ut, vt]
%         xstate = [Det(1:2); Det(3:4); x(3:4)]; % [center u, v, w, h, ut, vt]
        xstate = [Det(1:2); W;H; x(3:4)]; % [center u, v, w, h, ut, vt]
        
        Track{i}.states = [Track{i}.states, xstate];
        Track{i}.states_online = [Track{i}.states_online, xstate];
        Track{i}.frame = [Track{i}.frame, f];
        Track{i}.frame_online = [Track{i}.frame_online, f];
        Track{i}.Appearance = opt.learn*Track{i}.Appearance + (1-opt.learn)*Track{i}.HSV(:,1);
        Track{i}.AppearanceSet = [Track{i}.AppearanceSet, Track{i}.HSV(:,1)];
        
        % Learning (ON)
        Track{i}.learn_on = 1;
        
        
        if(Track{i}.not_detected == 0) % If the object is detected at the previous frame.
            Track{i}.re_detected = 0;
        else % If the object is not detected at the previous frame.
            Track{i}.re_detected = 1;
        end

        Track{i}.not_detected = 0;
        
        
%         if Track{i}.re_detected ==1
%             Track{i}.re_detected = 0;
%         end
%         if Track{i}.not_detected == 1
%             Track{i}.re_detected = 1;
%         end
        
        if(Track{i}.unreliable >0)
            Track{i}.unreliable = 0;
        end
        x = param.F*x;
        xu = x(1:2)-x(5:6)/2; xb = x(1:2)+x(5:6)/2;
        Size_H = x(6);
        if(xu(1)<1-opt.margin_u || xu(2)<1-opt.margin_v || xb(1)>opt.imgsz(2)+opt.margin_u || xb(2)>opt.imgsz(1)+opt.margin_v || Size_H < opt.s_size(1) || Size_H > opt.s_size(3) ) % Out of View + too small or too large
            Track{i}.survival = 0;
            Track{i}.learn_on = 0;
            Track{i}.graph_weight = [];
        end
    else % If detections are not associated
        Track{i}.X = param.F * Track{i}.X;
        Track{i}.P = param.F * Track{i}.P;
        Track{i}.graph_weight = [];
        x = Track{i}.X;
        xstate = [x(1:2); x(5:6); x(3:4)];
        Track{i}.unreliable = Track{i}.unreliable + 1;
        Track{i}.learn_on = 0;
        Track{i}.not_detected = 1;
        Track{i}.re_detected = 0;
        x = param.F*x;
        xu = x(1:2)-x(5:6)/2; xb = x(1:2)+x(5:6)/2;
        Size_H = x(6);
        if(xu(1)<1-opt.margin_u || xu(2)<1-opt.margin_v || xb(1)>opt.imgsz(2)+opt.margin_u || xb(2)>opt.imgsz(1)+opt.margin_v || Size_H < opt.s_size(1) || Size_H > opt.s_size(3) ) % Out of View + too small or too large
            Track{i}.survival = 0;
        end
        
        T_frame = Track{i}.frame(end);
        if(f - T_frame > opt.max_gap ) % Out of View + too small or too large
            Track{i}.survival = 0;
        end
    end
end