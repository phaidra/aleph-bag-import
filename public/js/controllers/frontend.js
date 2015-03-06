var app = angular.module('frontendApp', ['ngAnimate', 'ngSanitize', 'ui.bootstrap', 'ui.bootstrap.modal', 'ajoslin.promise-tracker', 'pasvaz.bindonce', 'frontendService']);


app.controller('FrontendCtrl', function($scope, $window, $modal, $log, FrontendService, promiseTracker) {

  // we will use this to track running ajax requests to show spinner
  $scope.loadingTracker = promiseTracker.register('loadingTrackerFrontend');

  $scope.alerts = [];

  $scope.initdata = '';
  $scope.current_user = '';

  $scope.acnumbers = [];
  $scope.inputacnumbers = [];

  $scope.init = function (initdata) {
    $scope.initdata = angular.fromJson(initdata);
    $scope.current_user = $scope.initdata.current_user;
    $scope.baseurl = $('head base').attr('href');
    if($scope.initdata.load_bags){
      $scope.getACNumbers();
    }
  };

  $scope.closeAlert = function(index) {
    $scope.alerts.splice(index, 1);
  };



  $scope.signin_open = function () {

      var modalInstance = $modal.open({
            templateUrl: $('head base').attr('href')+'views/modals/loginform.html',
            controller: SigninModalCtrl
      });
  };


    $scope.addACNumbers = function(){
        var promise = FrontendService.addACNumbers($scope.inputacnumbers);
        $scope.loadingTracker.addPromise(promise);
        promise.then(
          function(response) {
            $scope.form_disabled = false;
            $scope.alerts = response.data.alerts;
            $scope.inputacnumbers = [];
            $scope.getACNumbers();
          }
          ,function(response) {
            $scope.form_disabled = false;
            if(response.data){
              if(response.data.alerts){
                $scope.alerts = response.data.alerts;
              }
            }
          }
        );
    };

    $scope.getACNumbers = function(){
        var promise = FrontendService.getACNumbers();
        $scope.loadingTracker.addPromise(promise);
        promise.then(
          function(response) {
            $scope.form_disabled = false;
            $scope.alerts = response.data.alerts;
            $scope.acnumbers = response.data.acnumbers;
          }
          ,function(response) {
            $scope.form_disabled = false;
            if(response.data){
              if(response.data.alerts){
                $scope.alerts = response.data.alerts;
              }
            }
          }
        );
    };

    $scope.fetchMetadata = function(acnumber){
        var promise = FrontendService.fetchMetadata(acnumber);
        $scope.loadingTracker.addPromise(promise);
        promise.then(
          function(response) {
            $scope.form_disabled = false;
            $scope.alerts = response.data.alerts;
            $scope.getACNumbers();
          }
          ,function(response) {
            $scope.form_disabled = false;
            if(response.data){
              if(response.data.alerts){
                $scope.alerts = response.data.alerts;
              }
            }
          }
        );
    };

    $scope.createBag = function(acnumber){
        var promise = FrontendService.createBag(acnumber);
        $scope.loadingTracker.addPromise(promise);
        promise.then(
          function(response) {
            $scope.form_disabled = false;
            $scope.alerts = response.data.alerts;
            $scope.getACNumbers();
          }
          ,function(response) {
            $scope.form_disabled = false;
            if(response.data){
              if(response.data.alerts){
                $scope.alerts = response.data.alerts;
              }
            }
          }
        );
    };

    $scope.setLang = function(langKey) {
      $translate.use(langKey);
   };
});

var SigninModalCtrl = function ($scope, $modalInstance, FrontendService, promiseTracker) {

  $scope.user = {username: '', password: ''};
  $scope.alerts = [];

  $scope.baseurl = $('head base').attr('href');

  // we will use this to track running ajax requests to show spinner
  $scope.loadingTracker = promiseTracker('loadingTrackerFrontend');

  $scope.closeAlert = function(index) {
      $scope.alerts.splice(index, 1);
    };

    $scope.hitEnterSignin = function(evt){
      if(angular.equals(evt.keyCode,13)
          && !(angular.equals($scope.user.username,null) || angular.equals($scope.user.username,''))
          && !(angular.equals($scope.user.password,null) || angular.equals($scope.user.password,''))
          )
      $scope.signin();
    };

  $scope.signin = function () {

    $scope.form_disabled = true;

    var promise = FrontendService.signin($scope.user.username, $scope.user.password);
      $scope.loadingTracker.addPromise(promise);
      promise.then(
        function(response) {
          $scope.form_disabled = false;
          $scope.alerts = response.data.alerts;
          $modalInstance.close();
          var red = $('#signin').attr('data-redirect');
          if(red){
            window.location = red;
          }else{
            window.location = $scope.baseurl;
          }
        }
        ,function(response) {
          $scope.form_disabled = false;
          $scope.alerts = response.data.alerts;
            }
        );
    return;

  };

  $scope.cancel = function () {
    $modalInstance.dismiss('cancel');
  };
};
