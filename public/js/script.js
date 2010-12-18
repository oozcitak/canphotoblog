// Live preview of background image
$('#bgcolor').change(function() {
  applyBackground();
});

$('#bgimage').change(function() {
  applyBackground();
});

function applyBackground() {
  bgcolor = $('#bgcolor').val();
  bgimage = $('#bgimage').val();
  $('body').css('background-color', bgcolor);
  $('body').css('background-image', 'url("../img/backgrounds/' + bgimage + '")');
}
