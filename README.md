# README.md

## Image Dimension and Arrangement

To reduce image dimensions and arrange all demo images in a single row, you can use the following HTML and CSS:

### HTML Example
```html
<div class="image-container">
    <img src="demo1.jpg" width="300" height="428">
    <img src="demo2.jpg" width="300" height="428">
    <img src="demo3.jpg" width="300" height="428">
</div>
```

### CSS Example
```css
.image-container {
    display: flex;
    flex-direction: row;
    justify-content: space-between;
}
```

This will ensure that all images are displayed in a single row and adhere to the specified dimensions.