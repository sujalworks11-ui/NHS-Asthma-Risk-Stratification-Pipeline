T = readtable('cleaneddata.csv');
head(T);
summary(T);
%dropping patience column
T.PATIENT_ID = [];
% handling missing data 
% for smoker we have 1 for smoker and for nan assuming as non smoker we
% assign 0 
T.C_SMOKER(isnan(T.C_SMOKER)) = 0;
% for CHOL_HDL_RATIO we will impute 
medianCHOL = nanmedian(T.CHOL_HDL_RATIO);
T.CHOL_HDL_RATIO = fillmissing(T.CHOL_HDL_RATIO, 'constant' , medianCHOL);
% converting into categorical data
T.GENDER = categorical(T.GENDER);
T.POLLUTION_RISK_BAND = categorical(T.POLLUTION_RISK_BAND);
T.ASTHMA_WORSENED = categorical(T.ASTHMA_WORSENED);
% Exploratory Data Analysis
% ASTHMA_WORSENED 
subplot(2,2,1)
histogram(T.ASTHMA_WORSENED);
title('Distribution of asthma worsened')
xlabel('NO = 0 & YES = 1'), ylabel('Count')
%Age vs ASTHMA WORSENED
subplot(2,2,2)
boxplot(T.AGE,T.ASTHMA_WORSENED);
title('Age vs Asthma Worsened');
xlabel('ASTHMA_WORSENED'), ylabel('AGE');
%Pollution Risk
subplot(2,2,3)
histogram(T.POLLUTION_RISK_BAND);
title('Pollution risk Band');
%Family history
subplot(2,2,4)
scatter(T.AGE,T.SYS_BP,T.ASTHMA_WORSENED);
title('age vs BP outcome')
% feature selection
featureNames = {'AGE', 'GENDER', 'FAMILY_HISTORY', 'POLLUTION_RISK_BAND', ...
                'C_SMOKER', 'C_DIABETES'};

X = T(:, featureNames);
Y = T.ASTHMA_WORSENED;
% Dividing the data for testing and training
rng(123); %seed for reproducibility
cv = cvpartition(height(T),'HoldOut',0.3);
trainIdx = training(cv);
testIdx = test(cv);

XTrain = X(trainIdx, :);
YTrain = Y(trainIdx, :);
XTest = X(testIdx, :);
YTest = Y(testIdx);

%Decision tree
%treeModel = fitctree(XTrain, YTrain, 'PredictorNames', featureNames);
%view(treeModel,'Mode','graph');
% evaluation of decision tree
%predTree = predict(treeModel, XTest);
%accTree = sum(predTree == YTest) / length(YTest);
%fprintf('Decision Tree Accuracy: %.2f%%\n', accTree * 100);
%confusionchart(YTest, predTree);
%title('Confusion Matrix: Decision Tree');

%Random forest
% we use Bag which creates a random forest
%rfModel = fitcensemble(XTrain, YTrain, ...
%    'Method', 'Bag', ...
%   'NumLearningCycles', 50, ... % Train 50 trees
%    'Learners', templateTree('Reproducible', true)); % Ensure results are consistent
%evaluation
%predRF = predict(rfModel, XTest);
%accRF = sum(predRF == YTest) / length(YTest);
%fprintf('Random Forest Accuracy:      %.2f%%\n', accRF * 100);
%figure('Name', 'Confusion Matrix - Random Forest');
%confusionchart(YTest, predRF);
%title('Confusion Matrix: Random Forest');

%KNN
%for this we require numeric data so we convert categorical data into
%numerical data with the help of dummy encoding
%XTrain_Num = XTrain;
%XTrain_Num.GENDER = double(XTrain_Num.GENDER);
%XTrain_Num.POLLUTION_RISK_BAND = double(XTrain_Num.POLLUTION_RISK_BAND);
%knnModel = fitcknn(XTrain_Num, YTrain, 'NumNeighbors', 5, 'Standardize', 1);

%evaluation
%XTest_Num = XTest;
%XTest_Num.GENDER = double(XTest_Num.GENDER);
%XTest_Num.POLLUTION_RISK_BAND = double(XTest_Num.POLLUTION_RISK_BAND);
%predKNN = predict(knnModel, XTest_Num);
%accKNN = sum(predKNN == YTest) / length(YTest);
%fprintf('KNN Accuracy: %.2f%%\n', accKNN * 100);

% ROC AUC curves 
%[~, scoreTree] = predict(treeModel, XTest);
%[~, scoreRF] = predict(rfModel, XTest);
%[~, scoreKNN] = predict(knnModel, XTest_Num);

%calculating the AUC
%[Xtree, Ytree, Ttree, AUC_Tree] = perfcurve(YTest, scoreTree(:,2), '1');
%[Xrf, Yrf, Trf, AUC_RF] = perfcurve(YTest, scoreRF(:,2), '1');
%[Xknn, Yknn, Tknn, AUC_KNN] = perfcurve(YTest, scoreKNN(:,2), '1');

%ploting the ROC
%figure('Name', 'ROC Curve Comparison');
%plot(Xtree, Ytree, 'LineWidth', 2); hold on;
%plot(Xrf, Yrf, 'LineWidth', 2);
%plot(Xknn, Yknn, 'LineWidth', 2);
%xlabel('False Positive Rate (1 - Specificity)');
%ylabel('True Positive Rate (Sensitivity)');
%title('ROC Curve Comparison');
%grid on;
%legend(['Decision Tree (AUC = ' num2str(AUC_Tree, '%.2f') ')'], ...
 %      ['Random Forest (AUC = ' num2str(AUC_RF, '%.2f') ')'], ...
  %     ['KNN (AUC = ' num2str(AUC_KNN, '%.2f') ')'], ...
   %    'Random Guess', ...
    %   'Location', 'SouthEast');

%displaying the AUC
%fprintf('\n--- Area Under Curve (AUC) Results ---\n');
%fprintf('Decision Tree AUC: %.4f\n', AUC_Tree);
%fprintf('Random Forest AUC: %.4f\n', AUC_RF);
%fprintf('KNN AUC:           %.4f\n', AUC_KNN);

%since the models are only predicting 0 and being lazy we add weight/cost
%to the models so they predict the 1 which is very less in number
% decision tree
costMatrix = [0, 1; 5, 0]; 
treeModel = fitctree(XTrain, YTrain, ...
    'PredictorNames', featureNames, ...
    'Cost', costMatrix, ...
    'OptimizeHyperparameters', 'auto', ... % MATLAB finds best settings
    'HyperparameterOptimizationOptions', struct('ShowPlots', false, 'Verbose', 0));
view(treeModel,'Mode','graph');
%evaluation of decision tree
predTree = predict(treeModel, XTest);
accTree = sum(predTree == YTest) / length(YTest);
fprintf('Decision Tree Accuracy: %.2f%%\n', accTree * 100);
confusionchart(YTest, predTree);
title('Confusion Matrix: Decision Tree');
cmTree = confusionmat(YTest, predTree);
TN = cmTree(1,1);
FP = cmTree(1,2);
FN = cmTree(2,1);
TP = cmTree(2,2);
Sensitivity = TP / (TP + FN); % Also called Recall
Specificity = TN / (TN + FP);
Precision   = TP / (TP + FP);
Recall      = Sensitivity;    % Recall is the same as Sensitivity
F1_Score    = (2 * Precision * Recall) / (Precision + Recall);
fprintf('Sensitivity (Recall): %.2f%%\n', Sensitivity * 100);
fprintf('Specificity:          %.2f%%\n', Specificity * 100);
fprintf('Precision:            %.2f%%\n', Precision * 100);
fprintf('F1 Score:             %.4f\n', F1_Score);

%Random forest
rfModel = fitcensemble(XTrain, YTrain, ...
    'Method', 'RUSBoost', ...        % Changed from 'Bag' to 'RUSBoost'
    'NumLearningCycles', 100, ...    % Increase trees to 100 for stability
    'Learners', templateTree('MinLeafSize', 5));
% Calculating Feature Importance
imp = predictorImportance(rfModel);
% Plotting important features
figure('Name', 'Feature Importance');
bar(imp);
xticklabels(rfModel.PredictorNames);
xtickangle(45);
ylabel('Importance Score');
title('Which predictors matter most?');
grid on;
%evaluation
predRF = predict(rfModel, XTest);
accRF = sum(predRF == YTest) / length(YTest);
fprintf('Random Forest Accuracy:      %.2f%%\n', accRF * 100);
figure('Name', 'Confusion Matrix - Random Forest');
confusionchart(YTest, predRF);
title('Confusion Matrix: Random Forest');
cmRF = confusionmat(YTest, predRF);
TN = cmRF(1,1); 
FP = cmRF(1,2); 
FN = cmRF(2,1); 
TP = cmRF(2,2);
Sensitivity = TP / (TP + FN); % Also called Recall
Specificity = TN / (TN + FP);
Precision   = TP / (TP + FP);
Recall      = Sensitivity;    % Recall is same as Sensitivity
F1_Score    = (2 * Precision * Recall) / (Precision + Recall);
fprintf('Sensitivity (Recall): %.2f%%\n', Sensitivity * 100);
fprintf('Specificity:          %.2f%%\n', Specificity * 100);
fprintf('Precision:            %.2f%%\n', Precision * 100);
fprintf('F1 Score:             %.4f\n', F1_Score);

% KNN Model 
XTrain_Num = XTrain;
XTrain_Num.GENDER = double(XTrain_Num.GENDER);
XTrain_Num.POLLUTION_RISK_BAND = double(XTrain_Num.POLLUTION_RISK_BAND);
knnModel = fitcknn(XTrain_Num, YTrain, ...
    'NumNeighbors', 10, ...         % Increased from 5 to 10 to reduce noise
    'DistanceWeight', 'inverse', ... % CLOSER neighbors vote stronger
    'Standardize', 1, ...
    'Cost', costMatrix);
%evaluation
XTest_Num = XTest;
XTest_Num.GENDER = double(XTest_Num.GENDER);
XTest_Num.POLLUTION_RISK_BAND = double(XTest_Num.POLLUTION_RISK_BAND);
predKNN = predict(knnModel, XTest_Num);
accKNN = sum(predKNN == YTest) / length(YTest);
fprintf('KNN Accuracy: %.2f%%\n', accKNN * 100);
cmKNN = confusionmat(YTest, predKNN);
TN = cmKNN(1,1); 
FP = cmKNN(1,2); 
FN = cmKNN(2,1); 
TP = cmKNN(2,2);
Sensitivity = TP / (TP + FN); % Also called Recall
Specificity = TN / (TN + FP);
Precision   = TP / (TP + FP);
Recall      = Sensitivity;    % Recall is same as Sensitivity
F1_Score    = (2 * Precision * Recall) / (Precision + Recall);
fprintf('Sensitivity (Recall): %.2f%%\n', Sensitivity * 100);
fprintf('Specificity:          %.2f%%\n', Specificity * 100);
fprintf('Precision:            %.2f%%\n', Precision * 100);
fprintf('F1 Score:             %.4f\n', F1_Score);

% ROC AUC curves 
[~, scoreTree] = predict(treeModel, XTest);
[~, scoreRF] = predict(rfModel, XTest);
[~, scoreKNN] = predict(knnModel, XTest_Num);

%calculating the AUC
[Xtree, Ytree, Ttree, AUC_Tree] = perfcurve(YTest, scoreTree(:,2), '1');
[Xrf, Yrf, Trf, AUC_RF] = perfcurve(YTest, scoreRF(:,2), '1');
[Xknn, Yknn, Tknn, AUC_KNN] = perfcurve(YTest, scoreKNN(:,2), '1');

%ploting the ROC
figure('Name', 'ROC Curve Comparison');
plot(Xtree, Ytree, 'LineWidth', 2); hold on;
plot(Xrf, Yrf, 'LineWidth', 2);
plot(Xknn, Yknn, 'LineWidth', 2);
plot([0 1], [0 1], 'k--', 'LineWidth', 1, 'DisplayName', 'Random Guess');
xlabel('False Positive Rate (1 - Specificity)');
ylabel('True Positive Rate (Sensitivity)');
title('ROC Curve Comparison');
grid on;
legend(['Decision Tree (AUC = ' num2str(AUC_Tree, '%.2f') ')'], ...
     ['Random Forest (AUC = ' num2str(AUC_RF, '%.2f') ')'], ...
     ['KNN (AUC = ' num2str(AUC_KNN, '%.2f') ')'], ...
     'Random Guess', 'Location', 'SouthEast');

%displaying the AUC
fprintf('\n--- Area Under Curve (AUC) Results ---\n');
fprintf('Decision Tree AUC: %.4f\n', AUC_Tree);
fprintf('Random Forest AUC: %.4f\n', AUC_RF);
fprintf('KNN AUC:           %.4f\n', AUC_KNN);


