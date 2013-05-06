$(document).ready(function() {
  $('.alert-box.success').delay(5000).fadeOut(500);
  $('.alert-box.notice').delay(5000).fadeOut(500);
  $('.alert-box.alert').delay(9000).fadeOut(500);

  $('<i id="back-to-top" class="icon-chevron-up"></i>').appendTo($('body'));

  $(window).scroll(function() {

    if($(this).scrollTop() != 0) {
      $('#back-to-top').fadeIn();	
    } else {
      $('#back-to-top').fadeOut();
    }

  });
    
  $('#back-to-top').click(function() {
    $('body,html').animate({scrollTop:0},600);
  });

});
