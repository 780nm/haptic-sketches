from PIL import Image
import numpy as np

# Heavily modified from https://medium.com/analytics-vidhya/2d-convolution-using-python-numpy-43442ff5f381
def convolve2D(image, kernelR, kernelB):
    # Shape of Output Convolution
    xPix = image.shape[0]
    yPix = image.shape[1]
    output = np.zeros((xPix, yPix, 3))

    imagePadded = np.zeros((xPix + 2, yPix + 2, 3))
    imagePadded[1:-1, 1:-1, :] = image

    # Iterate through image
    for y in range(image.shape[1]):
        for x in range(image.shape[0]):
            if abs(imagePadded[x + 1, y + 1 , 0]) > 0.01 and abs(imagePadded[x + 1, y + 1 , 2]) > 0.01 :
                output[x, y] = imagePadded[x + 1, y + 1]
            elif imagePadded[x + 1, y + 1, 1] > 0.5:
                output[x, y] = [0.0,1.0,0.0]
            else:
                R = (kernelR * imagePadded[x: x + 3, y: y + 3]).sum()
                B = (kernelB * imagePadded[x: x + 3, y: y + 3]).sum()

                norm = np.linalg.norm([R,B])

                if norm < 0.5 :
                    output[x, y] = [0.0,0.0,0.0]
                else:
                    output[x, y] = [R/norm,0,B/norm]

    return output

def makeNormals(npImage):
    kernelR = np.array([[[1.,1.,0.],
                        [1.,0.,0.],
                        [1.,-1.,0.]],
                        [[1.,1.,0.],
                        [1.,0.,0.],
                        [1.,-1.,0.]],
                        [[1.,1.,0.],
                        [1.,0.,0.],
                        [1.,-1.,0.]]])
    kernelB = np.array([[[0.,1.,1.],
                        [0.,1.,1.],
                        [0.,1.,1.]],
                        [[0.,0.,1.],
                        [0.,0.,1.],
                        [0.,0.,1.]],
                        [[0.,-1.,1.],
                        [0.,-1.,1.],
                        [0.,-1.,1.]]])

    npImage = (npImage - [0x88, 0, 0x88])
    npImage = npImage / 255.0

    for i in range(int(max(npImage.shape[0], npImage.shape[1]) / 2)):
        out = convolve2D(npImage,kernelR,kernelB)
        npImage = out.copy()
        print("Done " + str(i))

    out [:, :] += [1, 0, 1]
    out [:, :] *= [127.5, 255, 127.5]
    return out.astype(np.uint8)

# Run

img = Image.open('Maze.png')
npOut = makeNormals(np.asarray(img))
Image.fromarray(npOut).save("out.png")
