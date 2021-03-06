angular.module('frontendService', ['Base64'])
.factory('FrontendService', function($http, Base64) {

  return {

    signin: function(username, password) {

         return $http({
             method  : 'GET',
             url     : $('head base').attr('href')+'signin',
             headers: {'Authorization': 'Basic ' + Base64.encode(username + ':' + password)}
         });
    },

    addACNumbers: function(acnumbers) {

         return $http({
             method  : 'POST',
             url     : $('head base').attr('href')+'import/acnumbers',
             data: {acnumbers: acnumbers}
         });
    },

    getACNumbers: function(acnumbers) {

         return $http({
             method  : 'GET',
             url     : $('head base').attr('href')+'import/acnumbers'
         });
    },

    fetchMetadata: function(acnumbers) {

         return $http({
             method  : 'POST',
             url     : $('head base').attr('href')+'import/fetch',
             data: {acnumbers: acnumbers}
         });
    },

    deleteAlerts: function(acnumbers) {

         return $http({
             method  : 'POST',
             url     : $('head base').attr('href')+'import/delete_alerts',
             data: {acnumbers: acnumbers}
         });
    },

    createOrUpdateBag: function(acnumbers) {

         return $http({
             method  : 'POST',
             url     : $('head base').attr('href')+'import/create_or_update_bag',
             data: {acnumbers: acnumbers}
         });
    }

  }
});
