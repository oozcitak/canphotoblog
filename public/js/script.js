// Live preview of background image
$('#bgcolor, #bgimage').change(function() {
  bgcolor = $('#bgcolor').val();
  bgimage = $('#bgimage').val();
  $('body').css('background-color', bgcolor);
  $('body').css('background-image', 'url("../img/backgrounds/' + bgimage + '")');
});

// Hide flash boxes on timeout
setTimeout(function() {
  $('.error').fadeOut('slow');
  $('.info').fadeOut('slow');
}, 1500);
