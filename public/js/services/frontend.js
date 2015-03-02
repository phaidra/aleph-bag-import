angular.module('frontendService', ['Base64'])
.factory('FrontendService', function($http, Base64) {

  return {

    signin: function(username, password) {

         return $http({
             method  : 'GET',
             url     : $('head base').attr('href')+'signin',
             headers: {'Authorization': 'Basic ' + Base64.encode(username + ':' + password)}
         });
    }

  }
});
